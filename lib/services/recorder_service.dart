import 'package:flutter/foundation.dart' as foundation;
import 'dart:async';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service for audio recording only (no ASR)
class RecorderService {
  static const MethodChannel _channel =
      MethodChannel('com.audionotes/recorder');

  /// Start recording and return the WAV file path when stopped
  Future<String?> startRecording() async {
    try {
      // Request microphone permission first
      final status = await Permission.microphone.request();

      if (!status.isGranted) {
        foundation.debugPrint('Microphone permission denied');
        return null;
      }

      final result = await _channel.invokeMethod('startRecording');
      return result as String?;
    } on PlatformException catch (e) {
      foundation.debugPrint('Failed to start recording: ${e.message}');
      return null;
    }
  }

  /// Stop recording and return the WAV file path
  Future<String?> stopRecording() async {
    try {
      final result = await _channel.invokeMethod('stopRecording');
      return result as String?;
    } on PlatformException catch (e) {
      foundation.debugPrint('Failed to stop recording: ${e.message}');
      return null;
    }
  }

  /// Cancel current recording without saving
  Future<bool> cancelRecording() async {
    try {
      final result = await _channel.invokeMethod('cancelRecording');
      return result == true;
    } on PlatformException catch (e) {
      foundation.debugPrint('Failed to cancel recording: ${e.message}');
      return false;
    }
  }

  /// Check if currently recording
  Future<bool> isRecording() async {
    try {
      final result = await _channel.invokeMethod('isRecording');
      return result == true;
    } on PlatformException catch (e) {
      foundation.debugPrint('Failed to check recording state: ${e.message}');
      return false;
    }
  }

  /// Start recording from widget intent
  Future<bool> startRecordingFromIntent() async {
    try {
      final result = await _channel.invokeMethod('startRecordingFromIntent');
      return result == true;
    } on PlatformException catch (e) {
      foundation.debugPrint('Failed to start recording from intent: ${e.message}');
      return false;
    }
  }
}
