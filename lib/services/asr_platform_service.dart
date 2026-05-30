import 'package:flutter/foundation.dart' as foundation;
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/speech_segment.dart';

/// Platform channel commands from Dart to Native
enum PlatformCommand {
  start('start'),
  stop('stop'),
  cancel('cancel'),
  reRecord('reRecord'),
  setVADParams('setVADParams');

  final String value;
  const PlatformCommand(this.value);
}

/// Platform channel events from Native to Dart
enum PlatformEvent {
  partialTranscript('partial_transcript'),
  finalSegment('final_segment'),
  vadBoundary('vad_boundary'),
  error('error'),
  modelStatus('model_status');

  final String value;
  const PlatformEvent(this.value);

  static PlatformEvent? fromValue(String value) {
    return PlatformEvent.values.firstWhere(
      (e) => e.value == value,
      orElse: () => throw ArgumentError('Unknown event: $value'),
    );
  }
}

/// VAD configuration parameters
class VADConfig {
  final int shortPauseMs;
  final int longPauseMs;
  final double energyThreshold;

  const VADConfig({
    this.shortPauseMs = 600,
    this.longPauseMs = 1500,
    this.energyThreshold = 0.3,
  });

  Map<String, dynamic> toMap() {
    return {
      'short_pause_ms': shortPauseMs,
      'long_pause_ms': longPauseMs,
      'energy_threshold': energyThreshold,
    };
  }
}

/// Audio recording configuration
class AudioConfig {
  final int sampleRate;
  final int channels;
  final String format;

  const AudioConfig({
    this.sampleRate = 16000,
    this.channels = 1,
    this.format = 'pcm16',
  });

  Map<String, dynamic> toMap() {
    return {
      'sampleRate': sampleRate,
      'channels': channels,
      'format': format,
    };
  }
}

/// Service for communicating with native platform code
class ASRPlatformService {
  static const MethodChannel _channel = MethodChannel('com.audionotes/asr');

  final _eventController = StreamController<Map<String, dynamic>>.broadcast();

  /// Stream of all platform events
  Stream<Map<String, dynamic>> get eventStream => _eventController.stream;

  /// Stream of partial transcripts
  Stream<PartialTranscript> get partialTranscriptStream {
    return eventStream
        .where(
            (event) => event['event'] == PlatformEvent.partialTranscript.value)
        .map((event) => PartialTranscript.fromMap(event));
  }

  /// Stream of final speech segments
  Stream<SpeechSegment> get finalSegmentStream {
    return eventStream
        .where((event) => event['event'] == PlatformEvent.finalSegment.value)
        .map((event) => SpeechSegment.fromMap(event));
  }

  /// Stream of errors
  Stream<String> get errorStream {
    return eventStream
        .where((event) => event['event'] == PlatformEvent.error.value)
        .map((event) => event['message'] as String? ?? 'Unknown error');
  }

  ASRPlatformService() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    try {
      final arguments = call.arguments as Map<dynamic, dynamic>?;
      if (arguments != null) {
        final Map<String, dynamic> event = Map<String, dynamic>.from(arguments);
        _eventController.add(event);
      }
    } catch (e) {
      foundation.debugPrint('Error handling method call: $e');
    }
  }

  /// Start audio recording and ASR
  Future<bool> startRecording(AudioConfig config) async {
    try {
      // Request microphone permission first
      final status = await Permission.microphone.request();

      if (!status.isGranted) {
        foundation.debugPrint('Microphone permission denied');
        return false;
      }

      final result = await _channel.invokeMethod('start', config.toMap());
      return result == true;
    } on PlatformException catch (e) {
      foundation.debugPrint('Failed to start recording: ${e.message}');
      return false;
    }
  }

  /// Stop recording and finalize current segment
  Future<bool> stopRecording() async {
    try {
      final result = await _channel.invokeMethod('stop');
      return result == true;
    } on PlatformException catch (e) {
      foundation.debugPrint('Failed to stop recording: ${e.message}');
      return false;
    }
  }

  /// Cancel current recording without saving
  Future<bool> cancelRecording() async {
    try {
      final result = await _channel.invokeMethod('cancel');
      return result == true;
    } on PlatformException catch (e) {
      foundation.debugPrint('Failed to cancel recording: ${e.message}');
      return false;
    }
  }

  /// Re-record a specific segment by ID
  Future<bool> reRecordSegment(String segmentId) async {
    try {
      final result =
          await _channel.invokeMethod('reRecord', {'segment_id': segmentId});
      return result == true;
    } on PlatformException catch (e) {
      foundation.debugPrint('Failed to re-record segment: ${e.message}');
      return false;
    }
  }

  /// Configure VAD parameters
  Future<bool> setVADConfig(VADConfig config) async {
    try {
      final result =
          await _channel.invokeMethod('setVADParams', config.toMap());
      return result == true;
    } on PlatformException catch (e) {
      foundation.debugPrint('Failed to set VAD config: ${e.message}');
      return false;
    }
  }

  /// Reload Vosk model (call after downloading a new model)
  Future<bool> reloadModel() async {
    try {
      final result = await _channel.invokeMethod('reloadModel');
      return result == true;
    } on PlatformException catch (e) {
      foundation.debugPrint('Failed to reload model: ${e.message}');
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _eventController.close();
  }
}
