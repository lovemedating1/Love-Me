import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'photo_picker_service.dart' show RecordedVoice;

/// Records short voice messages to an m4a file, then returns the bytes for
/// upload. Wraps the stateful `record` recorder (start → stop → read).
class VoiceRecorderService {
  VoiceRecorderService({AudioRecorder? recorder})
      : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  String? _path;

  /// True if mic permission is granted (prompts if needed).
  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<bool> get isRecording => _recorder.isRecording();

  /// Begins recording to a temp m4a file. Returns false if permission denied.
  Future<bool> start() async {
    if (!await _recorder.hasPermission()) return false;
    final dir = await getTemporaryDirectory();
    _path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: _path!,
    );
    return true;
  }

  /// Stops recording and returns the recorded audio, or `null` if nothing was
  /// captured / the file is empty.
  Future<RecordedVoice?> stop() async {
    final path = await _recorder.stop();
    if (path == null) return null;
    final file = File(path);
    if (!await file.exists()) return null;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return null;
    return RecordedVoice(bytes: bytes);
  }

  /// Cancels the current recording and discards it.
  Future<void> cancel() async {
    await _recorder.cancel();
    _path = null;
  }

  Future<void> dispose() => _recorder.dispose();
}

final voiceRecorderServiceProvider = Provider<VoiceRecorderService>((ref) {
  final service = VoiceRecorderService();
  ref.onDispose(service.dispose);
  return service;
});
