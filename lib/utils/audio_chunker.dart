import 'package:flutter/foundation.dart' as foundation;
import 'dart:io';

/// Utility for splitting long audio files into chunks for better recognition
class AudioChunker {
  static const int maxChunkDurationMs = 60000; // 60 seconds per chunk
  static const int sampleRate = 16000;
  static const int bytesPerSample = 2; // 16-bit PCM

  /// Split a WAV file into chunks if it's too long
  Future<List<String>> splitIfNeeded(String wavPath) async {
    final file = File(wavPath);

    if (!await file.exists()) {
      throw Exception('WAV file not found: $wavPath');
    }

    final fileSize = await file.length();
    final durationMs = _calculateDurationMs(fileSize);

    // If audio is shorter than max duration, return as-is
    if (durationMs <= maxChunkDurationMs) {
      return [wavPath];
    }

    foundation
        .debugPrint('Audio is $durationMs ms long, splitting into chunks...');

    // Read the entire file
    final data = await file.readAsBytes();

    // Skip WAV header (44 bytes)
    final pcmData = data.sublist(44);

    // Calculate chunk size in samples
    final samplesPerChunk = (sampleRate * maxChunkDurationMs / 1000).toInt();
    final bytesPerChunk = samplesPerChunk * bytesPerSample;

    final chunks = <String>[];
    final baseName = file.path.replaceAll('.wav', '');

    var offset = 0;
    var chunkIndex = 0;

    while (offset < pcmData.length) {
      final remaining = pcmData.length - offset;
      final currentChunkSize =
          remaining > bytesPerChunk ? bytesPerChunk : remaining;

      // Extract chunk data
      final chunkData = pcmData.sublist(offset, offset + currentChunkSize);

      // Create new WAV file for this chunk
      final chunkPath = '${baseName}_chunk_$chunkIndex.wav';
      final chunkFile = File(chunkPath);

      // Write WAV header + chunk data
      await _writeWavFile(chunkFile, chunkData);

      chunks.add(chunkPath);

      offset += currentChunkSize;
      chunkIndex++;
    }

    final chunkCount = chunks.length;
    foundation.debugPrint('Split into $chunkCount chunks');
    return chunks;
  }

  /// Merge recognition results from multiple chunks
  String mergeResults(List<String> chunkResults) {
    // Filter out empty results and join with spaces
    return chunkResults.where((result) => result.trim().isNotEmpty).join(' ');
  }

  int _calculateDurationMs(int fileSize) {
    // Subtract WAV header size
    final pcmSize = fileSize - 44;
    // Calculate duration: bytes / (sampleRate * channels * bytesPerSample) * 1000
    return (pcmSize / (sampleRate * 1 * bytesPerSample) * 1000).toInt();
  }

  Future<void> _writeWavFile(File file, List<int> pcmData) async {
    final sink = file.openWrite();

    try {
      // RIFF header
      sink.add([82, 73, 70, 70]); // "RIFF"
      sink.add(_intToLittleEndian(36 + pcmData.length));
      sink.add([87, 65, 86, 69]); // "WAVE"

      // fmt chunk
      sink.add([102, 109, 116, 32]); // "fmt "
      sink.add(_intToLittleEndian(16)); // Subchunk1Size
      sink.add([1, 0]); // AudioFormat (PCM)
      sink.add([1, 0]); // NumChannels (Mono)
      sink.add(_intToLittleEndian(sampleRate)); // SampleRate
      sink.add(_intToLittleEndian(sampleRate * 2)); // ByteRate
      sink.add([2, 0]); // BlockAlign
      sink.add([16, 0]); // BitsPerSample

      // data chunk
      sink.add([100, 97, 116, 97]); // "data"
      sink.add(_intToLittleEndian(pcmData.length));

      // PCM data
      sink.add(pcmData);

      await sink.flush();
    } finally {
      await sink.close();
    }
  }

  List<int> _intToLittleEndian(int value) {
    return [
      value & 0xFF,
      (value >> 8) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 24) & 0xFF,
    ];
  }
}
