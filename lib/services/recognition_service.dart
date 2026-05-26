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

  /// Recognize a WAV file and return detailed result including text and
  /// optional confidence score from the platform ASR.
  /// Returns a map: { 'text': String, 'confidence': double? }
  Future<Map<String, dynamic>?> recognizeDetailed(String wavPath) async {
    List<String> chunks = [wavPath];

    try {
      chunks = await _chunker.splitIfNeeded(wavPath);

      if (chunks.length == 1) {
        final result = await _channel.invokeMethod('recognize', {
          'wav_path': chunks.first,
          'detailed': true,
        });

        if (result == null) return null;

        if (result is Map) {
          // Expect {'text': '...', 'confidence': 0.87}
          return Map<String, dynamic>.from(result);
        } else {
          // Fallback: string
          return {'text': result.toString(), 'confidence': null};
        }
      } else {
        final texts = <String>[];
        final confidences = <double>[];

        for (final chunk in chunks) {
          final result = await _channel.invokeMethod('recognize', {
            'wav_path': chunk,
            'detailed': true,
          });

          if (result == null) continue;
          if (result is Map) {
            final text = (result['text'] ?? '').toString();
            texts.add(text);
            final conf = result['confidence'];
            if (conf is num) confidences.add(conf.toDouble());
          } else {
            final s = result.toString();
            if (s.isNotEmpty) texts.add(s);
          }
        }

        final merged = _chunker.mergeResults(texts);
        double? avgConf;
        if (confidences.isNotEmpty) {
          avgConf = confidences.reduce((a, b) => a + b) / confidences.length;
        }
        return {'text': merged, 'confidence': avgConf};
      }
    } on PlatformException catch (e) {
      print('Failed to recognize audio (detailed): ${e.message}');
      rethrow;
    } finally {
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
