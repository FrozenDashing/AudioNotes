import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/settings_provider.dart';
import '../models/model_metadata.dart';
import '../repositories/model_repository.dart';

/// Screen for selecting and managing speech recognition models
class ModelSelectionScreen extends ConsumerStatefulWidget {
  const ModelSelectionScreen({super.key});

  @override
  ConsumerState<ModelSelectionScreen> createState() =>
      _ModelSelectionScreenState();
}

class _ModelSelectionScreenState extends ConsumerState<ModelSelectionScreen> {
  late Future<List<ModelMetadata>> _modelsFuture;

  @override
  void initState() {
    super.initState();
    _modelsFuture = _loadModels();
  }

  Future<List<ModelMetadata>> _loadModels() async {
    final repo = ModelRepository();
    return await repo.getAllModels();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('选择语音模型'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FutureBuilder<List<ModelMetadata>>(
        future: _modelsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final models = snapshot.data ?? [];

          if (models.isEmpty) {
            return const Center(
              child: Text('暂无可用模型'),
            );
          }

          return ListView.builder(
            itemCount: models.length,
            itemBuilder: (context, index) {
              final model = models[index];
              return ModelCard(
                model: model,
                onDownload: () => _handleDownload(model),
                onDelete: () => _handleDelete(model),
                onSelect: () => _handleSelect(model),
              );
            },
          );
        },
      ),
    );
  }

  void _handleDownload(ModelMetadata model) {
    // Simulate download process
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('下载模型'),
        content: const Text('确认下载此语音识别模型？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              // In a real app, this would start the actual download
              _simulateDownload(model);
              Navigator.pop(context);
            },
            child: const Text('下载'),
          ),
        ],
      ),
    );
  }

  void _handleDelete(ModelMetadata model) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除模型'),
        content: const Text('确认删除此语音识别模型？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);
              final repo = ModelRepository();
              await repo.deleteModel(model.modelId);
              final settingsNotifier = ref.read(settingsProvider.notifier);
              if (ref.read(settingsProvider).currentModelId == model.modelId) {
                await settingsNotifier.setCurrentModelId('auto');
                await settingsNotifier.setAutoModelSelect(true);
              }

              // Refresh the list
              setState(() {
                _modelsFuture = _loadModels();
              });

              navigator.pop();
              messenger.showSnackBar(
                const SnackBar(content: Text('模型已删除')),
              );
            },
            child: const Text('删除'),
          ),
        ],
      ),
    );
  }

  void _handleSelect(ModelMetadata model) async {
    final navigator = Navigator.of(context);
    if (!model.isDownloaded) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先下载模型')),
      );
      return;
    }

    await ref.read(settingsProvider.notifier).setCurrentModelId(model.modelId);
    await ref.read(settingsProvider.notifier).setAutoModelSelect(false);
    navigator.pop(model.modelId);
  }

  Future<void> _simulateDownload(ModelMetadata model) async {
    final repo = ModelRepository();

    // Simulate download progress
    final updatedModel = model.copyWith(
      isDownloaded: true,
      downloadedAt: DateTime.now(),
      path: '/models/${model.modelId}',
    );

    await repo.updateModel(updatedModel);

    if (!context.mounted) {
      return;
    }

    // Refresh the list
    setState(() {
      _modelsFuture = _loadModels();
    });

    debugPrint('${model.name} 已下载完成');
  }
}

/// Widget for displaying a model card
class ModelCard extends StatelessWidget {
  final ModelMetadata model;
  final VoidCallback onDownload;
  final VoidCallback onDelete;
  final VoidCallback onSelect;

  const ModelCard({
    super.key,
    required this.model,
    required this.onDownload,
    required this.onDelete,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        model.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '版本: ${model.version}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                if (model.isDownloaded) ...[
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                ],
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'select') {
                      onSelect();
                    } else if (value == 'download' && !model.isDownloaded) {
                      onDownload();
                    } else if (value == 'delete' && model.isDownloaded) {
                      onDelete();
                    }
                  },
                  itemBuilder: (context) {
                    final items = <PopupMenuEntry<String>>[];

                    // Add "Set as current" option if model is downloaded
                    if (model.isDownloaded) {
                      items.add(const PopupMenuItem(
                        value: 'select',
                        child: Text('设为当前'),
                      ));
                    }

                    // Add "Download" option if not downloaded
                    if (!model.isDownloaded) {
                      items.add(const PopupMenuItem(
                        value: 'download',
                        child: Text('下载'),
                      ));
                    }

                    // Add "Delete" option if downloaded
                    if (model.isDownloaded) {
                      items.add(const PopupMenuItem(
                        value: 'delete',
                        child: Text('删除'),
                      ));
                    }

                    return items;
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(Icons.more_vert),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _getPerformanceIcon(model.accuracyTag),
                  size: 16,
                  color: _getPerformanceColor(model.accuracyTag),
                ),
                const SizedBox(width: 4),
                Text(
                  _getPerformanceLabel(model.accuracyTag),
                  style: TextStyle(
                    fontSize: 12,
                    color: _getPerformanceColor(model.accuracyTag),
                  ),
                ),
                const Spacer(),
                Text(
                  '${(model.sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getPerformanceIcon(String accuracyTag) {
    if (accuracyTag.toLowerCase().contains('speed') ||
        accuracyTag.toLowerCase().contains('latency')) {
      return Icons.flash_on;
    } else if (accuracyTag.toLowerCase().contains('accuracy')) {
      return Icons.precision_manufacturing;
    }
    return Icons.info;
  }

  Color _getPerformanceColor(String accuracyTag) {
    if (accuracyTag.toLowerCase().contains('speed') ||
        accuracyTag.toLowerCase().contains('latency')) {
      return Colors.orange;
    } else if (accuracyTag.toLowerCase().contains('accuracy')) {
      return Colors.blue;
    }
    return Colors.grey;
  }

  String _getPerformanceLabel(String accuracyTag) {
    if (accuracyTag.toLowerCase().contains('speed') ||
        accuracyTag.toLowerCase().contains('latency')) {
      return '低延迟';
    } else if (accuracyTag.toLowerCase().contains('accuracy')) {
      return '高精度';
    }
    return accuracyTag;
  }
}
