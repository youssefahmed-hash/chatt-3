import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class AudioService {
  final AudioRecorder _recorder = AudioRecorder();

  StreamSubscription<Amplitude>? _amplitudeSubscription;

  final StreamController<double> _waveformController =
  StreamController<double>.broadcast();

  Stream<double> get waveformStream => _waveformController.stream;

  bool _isPaused = false;

  bool get isPaused => _isPaused;

  bool get isRecording => _recorder.isRecording;

  // ============================================================
  // START
  // ============================================================

  Future<String?> startRecording() async {
    if (!await _recorder.hasPermission()) {
      return null;
    }

    String path = '';

    if (!kIsWeb) {
      final dir = await getTemporaryDirectory();

      path =
      '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.m4a';
    }

    await _recorder.start(
      const RecordConfig(),
      path: path,
    );

    _isPaused = false;

    _startAmplitudeListener();

    return path;
  }

  // ============================================================
  // WAVEFORM
  // ============================================================

  void _startAmplitudeListener() {
    _amplitudeSubscription?.cancel();

    _amplitudeSubscription = _recorder
        .onAmplitudeChanged(
      const Duration(milliseconds: 80),
    )
        .listen((amplitude) {
      if (_isPaused) {
        return;
      }

      final current = amplitude.current;

      double normalized = (current + 60.0) / 60.0;

      normalized = normalized.clamp(0.0, 1.0);

      if (!_waveformController.isClosed) {
        _waveformController.add(normalized);
      }
    });
  }

  // ============================================================
  // PAUSE
  // ============================================================

  Future<void> pauseRecording() async {
    if (!_recorder.isRecording) {
      return;
    }

    if (_recorder.isPaused) {
      return;
    }

    await _recorder.pause();

    _isPaused = true;
  }

  // ============================================================
  // RESUME
  // ============================================================

  Future<void> resumeRecording() async {
    if (!_recorder.isPaused) {
      return;
    }

    await _recorder.resume();

    _isPaused = false;
  }

  // ============================================================
  // STOP
  // ============================================================

  Future<String?> stopRecording() async {
    await _amplitudeSubscription?.cancel();

    _amplitudeSubscription = null;

    _isPaused = false;

    return await _recorder.stop();
  }

  // ============================================================
  // CANCEL
  // ============================================================

  Future<void> cancelRecording() async {
    await _amplitudeSubscription?.cancel();

    _amplitudeSubscription = null;

    _isPaused = false;

    await _recorder.cancel();

    if (!_waveformController.isClosed) {
      _waveformController.add(0.0);
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  void dispose() {
    _amplitudeSubscription?.cancel();

    _amplitudeSubscription = null;

    _waveformController.close();

    _recorder.dispose();
  }
}