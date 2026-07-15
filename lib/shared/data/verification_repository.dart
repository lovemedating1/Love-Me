import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';

import '../models/verification_request.dart';
import 'profile_photo_repository.dart' show mapStorageError;

/// Private storage bucket for identity-verification documents/selfies —
/// deliberately NOT the `avatars` bucket (public, meant for profile
/// photos). Uploading a passport scan or selfie-with-ID to a public bucket
/// would make it reachable by anyone with the URL — see
/// `BACKEND_VERIFICATION_HANDOFF.md` §2 for the exact bucket/RLS this
/// assumes.
const kVerificationDocumentsBucket = 'verification-documents';

/// Identity verification — targets the `verification_requests` table and
/// `verification-documents` storage bucket proposed in
/// `BACKEND_VERIFICATION_HANDOFF.md`. **Neither exists server-side yet**;
/// every call here will fail until backend ships them (see
/// `VerificationFeatureUnavailableException`). The interface/shape is
/// final so the swap is a no-op once they land.
abstract interface class VerificationRepository {
  /// Uploads a document/selfie image to the private bucket and returns its
  /// **object path** (not a URL) — same pattern as chat media, since a
  /// reviewer-only signed URL is minted on demand, never a public one.
  Future<String> uploadDocument(
    Uint8List bytes, {
    required String fileExtension,
  });

  /// Submits a verification request once both the document and selfie have
  /// been uploaded.
  Future<void> submitRequest({
    required VerificationDocType documentType,
    required String documentPath,
    required String selfiePath,
  });

  /// The current user's most recent verification request, or `null` if
  /// they've never submitted one.
  Future<VerificationRequest?> myLatestRequest();
}

/// Thrown when the `verification_requests` table / `verification-documents`
/// bucket don't exist yet (Postgrest 42P01/PGRST205, or a storage 404) —
/// lets the UI show "not available yet" instead of a raw error.
class VerificationFeatureUnavailableException implements Exception {
  const VerificationFeatureUnavailableException();
}

class SupabaseVerificationRepository implements VerificationRepository {
  const SupabaseVerificationRepository();

  sb.SupabaseClient get _client => sb.Supabase.instance.client;

  Never _mapPostgrestError(Object e) {
    if (e is sb.PostgrestException &&
        (e.code == '42P01' || e.code == 'PGRST205')) {
      throw const VerificationFeatureUnavailableException();
    }
    throw e;
  }

  @override
  Future<String> uploadDocument(
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
          .from(kVerificationDocumentsBucket)
          .uploadBinary(
            path,
            bytes,
            fileOptions: sb.FileOptions(contentType: contentType, upsert: true),
          );
      return path;
    } catch (e) {
      final mapped = mapStorageError(e, kVerificationDocumentsBucket);
      if (mapped.isMissingBucket) {
        throw const VerificationFeatureUnavailableException();
      }
      throw mapped;
    }
  }

  @override
  Future<void> submitRequest({
    required VerificationDocType documentType,
    required String documentPath,
    required String selfiePath,
  }) async {
    final myId = _client.auth.currentUser!.id;
    try {
      await _client.from('verification_requests').insert({
        'user_id': myId,
        'document_type': documentType.wireValue,
        'document_path': documentPath,
        'selfie_path': selfiePath,
        'status': 'pending',
      });
    } catch (e) {
      _mapPostgrestError(e);
    }
  }

  @override
  Future<VerificationRequest?> myLatestRequest() async {
    try {
      final myId = _client.auth.currentUser!.id;
      final row = await _client
          .from('verification_requests')
          .select()
          .eq('user_id', myId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      return row == null ? null : VerificationRequest.fromJson(row);
    } catch (e) {
      _mapPostgrestError(e);
    }
  }
}
