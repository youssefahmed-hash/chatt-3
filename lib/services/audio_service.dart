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

  // ============================================================
  // IS RECORDING
  // ============================================================

  Future<bool> get isRecording async {
    return await _recorder.isRecording();
  }

  // ============================================================
  // START
  // ============================================================

  Future<String?> startRecording() async {
    try {
      final hasPermission = await _recorder.hasPermission();

      if (!hasPermission) {
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
    } catch (e) {
      debugPrint('AudioService START ERROR: $e');
      return null;
    }
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
        .listen(
          (amplitude) {
        if (_isPaused) {
          return;
        }

        final current = amplitude.current;

        // dBFS:
        // -60 = صوت هادي جدًا
        // 0   = صوت عالي جدًا
        double normalized = (current + 60.0) / 60.0;

        normalized = normalized.clamp(0.0, 1.0);

        if (!_waveformController.isClosed) {
          _waveformController.add(normalized);
        }
      },
      onError: (error) {
        debugPrint(
          'AudioService AMPLITUDE ERROR: $error',
        );
      },
    );
  }

  // ============================================================
  // PAUSE
  // ============================================================

  Future<void> pauseRecording() async {
    try {
      final recording = await _recorder.isRecording();

      if (!recording) {
        return;
      }

      final paused = await _recorder.isPaused();

      if (paused) {
        return;
      }

      await _recorder.pause();

      _isPaused = true;

      debugPrint('RECORDING PAUSED');
    } catch (e) {
      debugPrint(
        'AudioService PAUSE ERROR: $e',
      );
    }
  }

  // ============================================================
  // RESUME
  // ============================================================

  Future<void> resumeRecording() async {
    try {
      final paused = await _recorder.isPaused();

      if (!paused) {
        return;
      }

      await _recorder.resume();

      _isPaused = false;

      debugPrint('RECORDING RESUMED');
    } catch (e) {
      debugPrint(
        'AudioService RESUME ERROR: $e',
      );
    }
  }

  // ============================================================
  // STOP
  // ============================================================

  Future<String?> stopRecording() async {
    try {
      await _amplitudeSubscription?.cancel();

      _amplitudeSubscription = null;

      _isPaused = false;

      final path = await _recorder.stop();

      debugPrint(
        'RECORDING STOPPED: $path',
      );

      return path;
    } catch (e) {
      debugPrint(
        'AudioService STOP ERROR: $e',
      );

      return null;
    }
  }

  // ============================================================
  // CANCEL
  // ============================================================

  Future<void> cancelRecording() async {
    try {
      await _amplitudeSubscription?.cancel();

      _amplitudeSubscription = null;

      _isPaused = false;

      await _recorder.cancel();

      if (!_waveformController.isClosed) {
        _waveformController.add(0.0);
      }

      debugPrint('RECORDING CANCELLED');
    } catch (e) {
      debugPrint(
        'AudioService CANCEL ERROR: $e',
      );
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  void dispose() {
    _amplitudeSubscription?.cancel();

    _amplitudeSubscription = null;

    if (!_waveformController.isClosed) {
      _waveformController.close();
    }

    _recorder.dispose();
  }
}