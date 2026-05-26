import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import '../utils/audio_chunker.dart';

/// Service for speech recognition only (no recording)
class RecognitionService {
  static const MethodChannel _channel =
      MethodChannel('com.audionotes/recognition');
  final AudioChunker _chunker = AudioChunker();

  /// Recognize a WAV file and return the transcribed text
  /// Automatically splits long files into chunks if needed
  Future<String?> recognize(String wavPath) async {
    List<String> chunks = [wavPath];

    try {
      // Split file into chunks if it's too long
      chunks = await _chunker.splitIfNeeded(wavPath);

      if (chunks.length == 1) {
        // Single chunk, process normally
        final result = await _channel.invokeMethod('recognize', {
          'wav_path': chunks.first,
        });
        return result as String?;
      } else {
        // Multiple chunks, process each and merge
        print('Processing ${chunks.length} chunks...');

        final results = <String>[];
        for (int i = 0; i < chunks.length; i++) {
          print('Processing chunk ${i + 1}/${chunks.length}');

          final result = await _channel.invokeMethod('recognize', {
            'wav_path': chunks[i],
          });

          if (result != null && result.toString().isNotEmpty) {
            results.add(result.toString());
          }
        }

        // Merge results
        return _chunker.mergeResults(results);
      }
    } on PlatformException catch (e) {
      print('Failed to recognize audio: ${e.message}');
      rethrow;
    } finally {
      // Clean up temporary chunk files even if recognition fails
      for (final chunk in chunks) {
        if (chunk != wavPath) {
          try {
            await _deleteFile(chunk);
          } catch (e) {
            print('Error deleting chunk file: $e');
          }
        }
      }
    }
  }

  /// Check if model is loaded and ready
  Future<bool> isModelReady() async {
    try {
      final result = await _channel.invokeMethod('isModelReady');
      return result == true;
    } on PlatformException catch (e) {
      print('Failed to check model status: ${e.message}');
      return false;
    }
  }

  /// Reload model (call after downloading a new model)
  Future<bool> reloadModel() async {
    try {
      final result = await _channel.invokeMethod('reloadModel');
      return result == true;
    } on PlatformException catch (e) {
      print('Failed to reload model: ${e.message}');
      return false;
    }
  }

  Future<void> _deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
