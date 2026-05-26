import 'package:equatable/equatable.dart';

/// Represents metadata for a speech recognition model
class ModelMetadata extends Equatable {
  final String modelId;
  final String name;
  final int sizeBytes;
  final String version;
  final DateTime? downloadedAt;
  final String? path;
  final String? sha256;
  final String accuracyTag; // e.g., 'low-latency', 'high-accuracy'
  final bool isDownloaded;

  const ModelMetadata({
    required this.modelId,
    required this.name,
    required this.sizeBytes,
    required this.version,
    this.downloadedAt,
    this.path,
    this.sha256,
    required this.accuracyTag,
    this.isDownloaded = false,
  });

  ModelMetadata copyWith({
    String? modelId,
    String? name,
    int? sizeBytes,
    String? version,
    DateTime? downloadedAt,
    String? path,
    String? sha256,
    String? accuracyTag,
    bool? isDownloaded,
  }) {
    return ModelMetadata(
      modelId: modelId ?? this.modelId,
      name: name ?? this.name,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      version: version ?? this.version,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      path: path ?? this.path,
      sha256: sha256 ?? this.sha256,
      accuracyTag: accuracyTag ?? this.accuracyTag,
      isDownloaded: isDownloaded ?? this.isDownloaded,
    );
  }

  @override
  List<Object?> get props => [
        modelId,
        name,
        sizeBytes,
        version,
        downloadedAt,
        path,
        sha256,
        accuracyTag,
        isDownloaded,
      ];
}