import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

/// Where the user wants to source a photo from.
enum PhotoSource { camera, gallery }

/// A picked-and-validated photo, ready to upload.
class PickedPhoto {
  const PickedPhoto({required this.bytes, required this.fileExtension});

  final Uint8List bytes;
  final String fileExtension; // e.g. 'jpg', 'png'
}

/// The kind of chat media a user picked.
enum ChatMediaKind { image, video }

/// A picked chat-media file (image or video), ready to upload. For videos,
/// [thumbnailBytes] is a generated JPEG poster frame — the `messages` table
/// requires a `thumbnail_url` for video messages.
class PickedChatMedia {
  const PickedChatMedia({
    required this.kind,
    required this.bytes,
    required this.fileExtension,
    this.thumbnailBytes,
  });

  final ChatMediaKind kind;
  final Uint8List bytes;
  final String fileExtension;
  final Uint8List? thumbnailBytes; // non-null for video
}

/// A recorded voice message, ready to upload.
class RecordedVoice {
  const RecordedVoice({required this.bytes, this.fileExtension = 'm4a'});

  final Uint8List bytes;
  final String fileExtension;
}

/// Raised when the user picked an image that doesn't contain a detectable
/// human face — surfaced to the UI as "please upload a photo of a person".
class NoFaceDetectedException implements Exception {
  const NoFaceDetectedException();
}

/// Raised when the user cancels the picker (no photo chosen). Callers should
/// treat this as a silent no-op, not an error to toast.
class PhotoPickCancelled implements Exception {
  const PhotoPickCancelled();
}

/// Picks a profile photo from the camera or gallery and validates on-device
/// that it contains a human face before returning it. The authoritative
/// safety/human check is the server-side `moderate-image` edge function
/// (not built yet — see BACKEND_REMAINING.md [BE-5]); this is the fast,
/// offline first gate that rejects obviously non-person photos.
class PhotoPickerService {
  PhotoPickerService({ImagePicker? picker, FaceDetector? faceDetector})
    : _picker = picker ?? ImagePicker(),
      _faceDetector =
          faceDetector ?? FaceDetector(options: FaceDetectorOptions());

  final ImagePicker _picker;
  final FaceDetector _faceDetector;

  /// Picks + validates a profile photo. Throws [PhotoPickCancelled] if the
  /// user backs out, or [NoFaceDetectedException] if no face is found.
  Future<PickedPhoto> pickProfilePhoto(PhotoSource source) async {
    final xfile = await _picker.pickImage(
      source: source == PhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1440,
      maxHeight: 1440,
    );
    if (xfile == null) throw const PhotoPickCancelled();

    final hasFace = await _containsFace(xfile.path);
    if (!hasFace) throw const NoFaceDetectedException();

    final bytes = await xfile.readAsBytes();
    final ext = _extensionOf(xfile.path);
    return PickedPhoto(bytes: bytes, fileExtension: ext);
  }

  /// Picks an identity-verification document photo (ID card/passport/etc.) —
  /// no face-check, since a scanned document legitimately may not show a
  /// clear face crop the on-device detector would recognize. Throws
  /// [PhotoPickCancelled] if the user backs out.
  Future<PickedPhoto> pickVerificationDocument(PhotoSource source) async {
    final xfile = await _picker.pickImage(
      source: source == PhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      imageQuality: 90,
      maxWidth: 2000,
      maxHeight: 2000,
    );
    if (xfile == null) throw const PhotoPickCancelled();
    return PickedPhoto(
      bytes: await xfile.readAsBytes(),
      fileExtension: _extensionOf(xfile.path),
    );
  }

  /// Picks a chat image (no face-check — chat photos aren't required to be a
  /// person). Throws [PhotoPickCancelled] if the user backs out.
  Future<PickedChatMedia> pickChatImage(PhotoSource source) async {
    final xfile = await _picker.pickImage(
      source: source == PhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1920,
      maxHeight: 1920,
    );
    if (xfile == null) throw const PhotoPickCancelled();
    return PickedChatMedia(
      kind: ChatMediaKind.image,
      bytes: await xfile.readAsBytes(),
      fileExtension: _extensionOf(xfile.path),
    );
  }

  /// Picks a chat video and generates a JPEG thumbnail (required by the
  /// `messages` video constraint). Throws [PhotoPickCancelled] if cancelled.
  Future<PickedChatMedia> pickChatVideo(PhotoSource source) async {
    final xfile = await _picker.pickVideo(
      source: source == PhotoSource.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxDuration: const Duration(minutes: 1),
    );
    if (xfile == null) throw const PhotoPickCancelled();

    final thumb = await VideoThumbnail.thumbnailData(
      video: xfile.path,
      imageFormat: ImageFormat.JPEG,
      maxWidth: 640,
      quality: 75,
    );
    final ext = _extensionOf(xfile.path, fallback: 'mp4');
    return PickedChatMedia(
      kind: ChatMediaKind.video,
      bytes: await xfile.readAsBytes(),
      fileExtension: ext,
      thumbnailBytes: thumb,
    );
  }

  Future<bool> _containsFace(String path) async {
    final input = InputImage.fromFile(File(path));
    final faces = await _faceDetector.processImage(input);
    return faces.isNotEmpty;
  }

  String _extensionOf(String path, {String fallback = 'jpg'}) {
    final dot = path.lastIndexOf('.');
    if (dot == -1 || dot == path.length - 1) return fallback;
    final ext = path.substring(dot + 1).toLowerCase();
    // Storage bucket accepts common image types; normalize jpeg→jpg.
    if (ext == 'jpeg') return 'jpg';
    return ext;
  }

  /// Release the native ML Kit detector. Call when the owning object is
  /// disposed to avoid leaking the platform resource.
  Future<void> dispose() => _faceDetector.close();
}

/// Riverpod handle for [PhotoPickerService]. Disposed with the provider so the
/// underlying ML Kit face detector is released.
final photoPickerServiceProvider = Provider<PhotoPickerService>((ref) {
  final service = PhotoPickerService();
  ref.onDispose(service.dispose);
  return service;
});
