import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';

import '../models/profile_photo.dart';

/// Name of the Supabase Storage bucket that holds profile photos + gallery.
/// **Must exist in the Supabase project** (public bucket) — create it in the
/// dashboard if uploads fail with a bucket-not-found error.
const kAvatarsBucket = 'avatars';

/// Profile photo gallery — live against `profile_photos`
/// (migration 009_profile_photos.sql / 010_profile_photos_rls.sql) +
/// the `set_primary_profile_photo` RPC (013_rpc_functions.sql), plus the
/// `avatars` Supabase Storage bucket for the actual image files.
///
/// Callers are responsible for picking a free `displayOrder` (1-4) before
/// calling [addPhoto]; use [uploadPhoto] first to turn picked bytes into a
/// hosted URL.
abstract interface class ProfilePhotoRepository {
  Future<List<ProfilePhoto>> myPhotos();

  /// Gallery for an arbitrary user (e.g. a Discover card) — public read
  /// under the table's RLS (profile photos are visible to any signed-in
  /// user). Ordered by `display_order`.
  Future<List<ProfilePhoto>> photosFor(String userId);

  /// Uploads raw image bytes to the `avatars` bucket at
  /// `<user_id>/<uuid>.<ext>` and returns the public URL to store in a
  /// `profile_photos` row. Does NOT insert the row — call [addPhoto] with the
  /// returned URL.
  Future<String> uploadPhoto(Uint8List bytes, {required String fileExtension});

  /// Inserts a new gallery photo. If [isPrimary] is true (e.g. the very
  /// first photo), the `sync_primary_profile_photo` trigger automatically
  /// mirrors [photoUrl] onto `profiles.photo_url` — no separate call needed.
  Future<ProfilePhoto> addPhoto({
    required String photoUrl,
    required int displayOrder,
    bool isPrimary = false,
  });

  /// Switches which existing photo is primary via the
  /// `set_primary_profile_photo` RPC (also syncs `profiles.photo_url`).
  Future<void> setPrimary(String photoId);

  Future<void> deletePhoto(String photoId);
}

/// Thrown when uploading bytes to Supabase Storage fails. [message] is
/// user-presentable; [isMissingBucket] means the bucket hasn't been created
/// in the Supabase project yet (the most common setup mistake).
class MediaUploadException implements Exception {
  const MediaUploadException(this.message, {this.isMissingBucket = false});
  final String message;
  final bool isMissingBucket;

  @override
  String toString() => message;
}

/// Maps a Supabase Storage error into a [MediaUploadException] with a
/// human-readable reason instead of an opaque failure.
MediaUploadException mapStorageError(Object error, String bucket) {
  if (error is sb.StorageException) {
    final msg = error.message.toLowerCase();
    if (error.statusCode == '404' ||
        msg.contains('not found') ||
        msg.contains('bucket')) {
      return MediaUploadException(
        'Storage bucket "$bucket" does not exist. Create it in the Supabase '
        'dashboard (Storage → New bucket).',
        isMissingBucket: true,
      );
    }
    if (error.statusCode == '403' || msg.contains('row-level security')) {
      return MediaUploadException(
        'Not allowed to upload to "$bucket". Check the bucket\'s storage '
        'policies allow authenticated uploads.',
      );
    }
    return MediaUploadException('Upload failed: ${error.message}');
  }
  return MediaUploadException('Upload failed: $error');
}

/// Thrown when a `profile_photos` write violates a check constraint
/// (Postgres 23514 — empty `photo_url`, or `display_order` outside 1-4).
class ProfilePhotoConstraintException implements Exception {
  const ProfilePhotoConstraintException(this.message);
  final String message;
}

/// Thrown when a `profile_photos` insert collides with a unique constraint
/// (Postgres 23505 — the `display_order` slot is already taken, or a rare
/// concurrent-primary race). Caller should refresh and retry with a free slot.
class ProfilePhotoSlotTakenException implements Exception {
  const ProfilePhotoSlotTakenException();
}

class SupabaseProfilePhotoRepository implements ProfilePhotoRepository {
  const SupabaseProfilePhotoRepository();

  sb.SupabaseClient get _client => sb.Supabase.instance.client;

  @override
  Future<String> uploadPhoto(
    Uint8List bytes, {
    required String fileExtension,
  }) async {
    final myId = _client.auth.currentUser!.id;
    final path = '$myId/${const Uuid().v4()}.$fileExtension';
    final contentType = switch (fileExtension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };
    try {
      await _client.storage
          .from(kAvatarsBucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: sb.FileOptions(contentType: contentType, upsert: true),
          );
    } catch (e) {
      throw mapStorageError(e, kAvatarsBucket);
    }
    return _client.storage.from(kAvatarsBucket).getPublicUrl(path);
  }

  @override
  Future<List<ProfilePhoto>> myPhotos() async {
    final myId = _client.auth.currentUser!.id;
    final rows = await _client
        .from('profile_photos')
        .select()
        .eq('user_id', myId)
        .order('display_order');
    return (rows as List)
        .map((p) => ProfilePhoto.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<ProfilePhoto> addPhoto({
    required String photoUrl,
    required int displayOrder,
    bool isPrimary = false,
  }) async {
    final myId = _client.auth.currentUser!.id;
    try {
      final response = await _client
          .from('profile_photos')
          .insert({
            'user_id': myId,
            'photo_url': photoUrl,
            'display_order': displayOrder,
            'is_primary': isPrimary,
          })
          .select()
          .single();
      return ProfilePhoto.fromJson(response);
    } on sb.PostgrestException catch (e) {
      if (e.code == '23505') throw const ProfilePhotoSlotTakenException();
      if (e.code == '23514') throw ProfilePhotoConstraintException(e.message);
      rethrow;
    }
  }

  @override
  Future<List<ProfilePhoto>> photosFor(String userId) async {
    final rows = await _client
        .from('profile_photos')
        .select()
        .eq('user_id', userId)
        .order('display_order');
    return (rows as List)
        .map((p) => ProfilePhoto.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<void> setPrimary(String photoId) =>
      _client.rpc('set_primary_profile_photo', params: {'photo_id': photoId});

  @override
  Future<void> deletePhoto(String photoId) =>
      _client.from('profile_photos').delete().eq('id', photoId);
}
