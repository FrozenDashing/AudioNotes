import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Utility class for managing audio file lifecycle
class AudioFileCleanup {
  /// Clean up orphaned audio files that are not associated with any todo
  static Future<void> cleanOrphanedFiles(List<String> validAudioPaths) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${appDir.path}/recordings');

      if (!await recordingsDir.exists()) {
        return;
      }

      // Get all WAV files in the directory
      final wavFiles = <File>[];
      await for (final entity
          in recordingsDir.list(recursive: true, followLinks: false)) {
        if (entity is File && entity.path.endsWith('.wav')) {
          wavFiles.add(entity);
        }
      }

      // Create a set of valid paths for quick lookup
      final validPathSet = Set<String>.from(validAudioPaths);

      // Delete orphaned files
      for (final file in wavFiles) {
        if (!validPathSet.contains(file.path)) {
          try {
            await file.delete();
            print('Deleted orphaned audio file: ${file.path}');
          } catch (e) {
            print('Error deleting orphaned file ${file.path}: $e');
          }
        }
      }

      print('Audio cleanup completed. Checked ${wavFiles.length} files.');
    } catch (e) {
      print('Error during audio cleanup: $e');
    }
  }

  /// Get total size of audio files
  static Future<int> getTotalAudioSize() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${appDir.path}/recordings');

      if (!await recordingsDir.exists()) {
        return 0;
      }

      int totalSize = 0;
      await for (final entity
          in recordingsDir.list(recursive: true, followLinks: false)) {
        if (entity is File && entity.path.endsWith('.wav')) {
          totalSize += await entity.length();
        }
      }

      return totalSize;
    } catch (e) {
      print('Error calculating audio size: $e');
      return 0;
    }
  }

  /// Delete all audio files (use with caution!)
  static Future<void> deleteAllAudioFiles() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final recordingsDir = Directory('${appDir.path}/recordings');

      if (await recordingsDir.exists()) {
        await recordingsDir.delete(recursive: true);
        print('All audio files deleted');
      }
    } catch (e) {
      print('Error deleting all audio files: $e');
    }
  }
}
