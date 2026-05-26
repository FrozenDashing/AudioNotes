import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:archive/archive.dart';

/// Vosk model information
class VoskModel {
  final String name;
  final String language;
  final String version;
  final String downloadUrl;
  final int sizeMB;
  final bool isDownloaded;
  final String? localPath;

  const VoskModel({
    required this.name,
    required this.language,
    required this.version,
    required this.downloadUrl,
    required this.sizeMB,
    this.isDownloaded = false,
    this.localPath,
  });

  factory VoskModel.chineseLarge() {
    return const VoskModel(
      name: 'vosk-model-cn-0.22',
      language: 'zh-CN',
      version: '0.22',
      downloadUrl: 'https://alphacephei.com/vosk/models/vosk-model-cn-0.22.zip',
      sizeMB: 1800,
    );
  }

  factory VoskModel.chineseSmall() {
    return const VoskModel(
      name: 'vosk-model-small-cn-0.22',
      language: 'zh-CN',
      version: '0.22',
      downloadUrl:
          'https://alphacephei.com/vosk/models/vosk-model-small-cn-0.22.zip',
      sizeMB: 45,
    );
  }
}

/// Service for managing Vosk model downloads and loading
class ModelManagerService {
  /// Check if a model is already downloaded
  Future<bool> isModelDownloaded(String modelName) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final modelPath = Directory('${appDir.path}/$modelName');
      return await modelPath.exists();
    } catch (e) {
      print('Error checking model: $e');
      return false;
    }
  }

  /// Get the local path of a downloaded model
  Future<String?> getModelPath(String modelName) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final modelPath = Directory('${appDir.path}/$modelName');
      if (await modelPath.exists()) {
        return modelPath.path;
      }
      return null;
    } catch (e) {
      print('Error getting model path: $e');
      return null;
    }
  }

  /// Download and extract a Vosk model
  /// Returns progress as a percentage (0.0 to 1.0)
  Stream<double> downloadModel(VoskModel model) async* {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final zipPath = '${appDir.path}/${model.name}.zip';
      final extractPath = appDir.path;

      // Download the model
      yield 0.1;

      final client = http.Client();
      final request = http.Request('GET', Uri.parse(model.downloadUrl));
      final response = await client.send(request);

      final contentLength = response.contentLength ?? 0;
      var bytesReceived = 0;

      final sink = File(zipPath).openWrite();
      await for (final chunk in response.stream) {
        bytesReceived += chunk.length;
        sink.add(chunk);

        // Report progress (10% - 70%)
        if (contentLength > 0) {
          final progress = 0.1 + (bytesReceived / contentLength) * 0.6;
          yield progress;
        }
      }
      await sink.close();
      client.close();

      yield 0.7;

      // Extract the ZIP file
      yield 0.75;

      final zipFile = File(zipPath);
      final bytes = await zipFile.readAsBytes();
      final archive = ZipDecoder().decodeBytes(bytes);

      var extractedFiles = 0;
      final totalFiles = archive.length;

      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final data = file.content as List<int>;
          final outFile = File('$extractPath/$filename');
          await outFile.create(recursive: true);
          await outFile.writeAsBytes(data);

          extractedFiles++;
          // Report extraction progress (75% - 95%)
          yield 0.75 + (extractedFiles / totalFiles) * 0.2;
        } else {
          await Directory('$extractPath/$filename').create(recursive: true);
        }
      }

      yield 0.95;

      // Clean up ZIP file
      await zipFile.delete();

      yield 1.0;
    } catch (e) {
      print('Error downloading model: $e');
      throw Exception('Failed to download model: $e');
    }
  }

  /// Delete a downloaded model
  Future<bool> deleteModel(String modelName) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final modelPath = Directory('${appDir.path}/$modelName');

      if (await modelPath.exists()) {
        await modelPath.delete(recursive: true);
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting model: $e');
      return false;
    }
  }

  /// Get available storage space
  Future<int> getAvailableStorage() async {
    try {
      // This is approximate - actual implementation may vary by platform
      return 1073741824; // Return 1GB as default
    } catch (e) {
      print('Error getting storage: $e');
      return 0;
    }
  }

  /// Check if there's enough storage for a model
  Future<bool> hasEnoughStorage(VoskModel model) async {
    final available = await getAvailableStorage();
    final needed = model.sizeMB * 1024 * 1024;
    return available >= needed;
  }
}
