import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../models/model_metadata.dart';

/// Repository for managing speech recognition models
class ModelRepository {
  static const String _modelsKey = 'model_metadata';

  List<ModelMetadata> _defaultModels() {
    return [
      const ModelMetadata(
        modelId: 'vosk-model-small-cn-0.22',
        name: '中文轻量模型',
        sizeBytes: 45 * 1024 * 1024,
        version: '0.22',
        accuracyTag: 'low-latency',
      ),
      const ModelMetadata(
        modelId: 'vosk-model-cn-0.22',
        name: '中文高精度模型',
        sizeBytes: 1800 * 1024 * 1024,
        version: '0.22',
        accuracyTag: 'high-accuracy',
      ),
    ];
  }

  /// Get all model metadata
  Future<List<ModelMetadata>> getAllModels() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_modelsKey);

    try {
      final List<ModelMetadata> storedModels;
      if (jsonString == null || jsonString.isEmpty) {
        storedModels = _defaultModels();
      } else {
        final List<dynamic> jsonList = json.decode(jsonString);
        storedModels = jsonList.map((json) => _fromJson(json)).toList();
      }

      final syncedModels = await _syncDownloadState(storedModels);
      if (jsonString == null || jsonString.isEmpty) {
        await saveAllModels(syncedModels);
      }
      return syncedModels;
    } catch (e) {
      print('Error parsing model metadata: $e');
      final defaults = await _syncDownloadState(_defaultModels());
      await saveAllModels(defaults);
      return defaults;
    }
  }

  /// Save all model metadata
  Future<bool> saveAllModels(List<ModelMetadata> models) async {
    final prefs = await SharedPreferences.getInstance();

    try {
      final jsonList = models.map((model) => _toJson(model)).toList();
      final jsonString = json.encode(jsonList);
      return await prefs.setString(_modelsKey, jsonString);
    } catch (e) {
      print('Error saving model metadata: $e');
      return false;
    }
  }

  /// Update a specific model's metadata
  Future<bool> updateModel(ModelMetadata model) async {
    final models = await getAllModels();
    final existingIndex = models.indexWhere((m) => m.modelId == model.modelId);

    if (existingIndex != -1) {
      models[existingIndex] = model;
    } else {
      models.add(model);
    }

    return await saveAllModels(models);
  }

  /// Get a specific model by ID
  Future<ModelMetadata?> getModelById(String modelId) async {
    final models = await getAllModels();
    try {
      return models.firstWhere((model) => model.modelId == modelId);
    } catch (e) {
      // If no element is found, firstWhere throws, so return null
      return null;
    }
  }

  /// Delete a model
  Future<bool> deleteModel(String modelId) async {
    final models = await getAllModels();
    final updatedModels =
        models.where((model) => model.modelId != modelId).toList();
    await _deleteModelFiles(modelId);
    return await saveAllModels(updatedModels);
  }

  Future<List<ModelMetadata>> _syncDownloadState(
      List<ModelMetadata> models) async {
    final appDir = await getApplicationDocumentsDirectory();
    final synced = <ModelMetadata>[];

    for (final model in models) {
      final modelDirectory = Directory('${appDir.path}/${model.modelId}');
      final isDownloaded = await modelDirectory.exists();
      synced.add(
        model.copyWith(
          isDownloaded: isDownloaded,
          path: isDownloaded ? modelDirectory.path : null,
        ),
      );
    }

    return synced;
  }

  Future<void> _deleteModelFiles(String modelId) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final modelDirectory = Directory('${appDir.path}/$modelId');
      if (await modelDirectory.exists()) {
        await modelDirectory.delete(recursive: true);
      }
    } catch (e) {
      print('Error deleting model files: $e');
    }
  }

  /// Convert ModelMetadata to JSON
  Map<String, dynamic> _toJson(ModelMetadata model) {
    return {
      'modelId': model.modelId,
      'name': model.name,
      'sizeBytes': model.sizeBytes,
      'version': model.version,
      'downloadedAt': model.downloadedAt?.millisecondsSinceEpoch,
      'path': model.path,
      'sha256': model.sha256,
      'accuracyTag': model.accuracyTag,
      'isDownloaded': model.isDownloaded,
    };
  }

  /// Convert JSON to ModelMetadata
  ModelMetadata _fromJson(Map<String, dynamic> json) {
    return ModelMetadata(
      modelId: json['modelId'] ?? '',
      name: json['name'] ?? 'Unknown Model',
      sizeBytes: json['sizeBytes'] ?? 0,
      version: json['version'] ?? '1.0',
      downloadedAt: json['downloadedAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['downloadedAt'])
          : null,
      path: json['path'],
      sha256: json['sha256'],
      accuracyTag: json['accuracyTag'] ?? 'default',
      isDownloaded: json['isDownloaded'] ?? false,
    );
  }
}
