import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_i18n.dart';
import '../providers/settings_provider.dart';
import '../models/model_metadata.dart';
import '../repositories/model_repository.dart';
import '../services/model_manager_service.dart';
import '../providers/app_providers.dart';

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
        title: Text(context.tr('model.selectVoiceModel')),
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
            return Center(
              child:
                  Text('${context.tr('model.errorPrefix')}: ${snapshot.error}'),
            );
          }

          final models = snapshot.data ?? [];

          if (models.isEmpty) {
            return Center(
              child: Text(context.tr('model.noModels')),
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
    final manager = ref.read(modelManagerServiceProvider);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        double progress = 0.0;
        StreamSubscription<double>? sub;

        void startDownload() async {
          final voskModel = model.modelId.contains('small')
              ? VoskModel.chineseSmall()
              : VoskModel.chineseLarge();

          final stream = manager.downloadModel(voskModel);
          sub = stream.listen((p) async {
            progress = p;
            if (context.mounted) setState(() {});
            if (p >= 1.0) {
              // Finalize: mark model downloaded in repo
              final repo = ModelRepository();
              final path = await manager.getModelPath(voskModel.name);
              final updated = model.copyWith(
                isDownloaded: true,
                downloadedAt: DateTime.now(),
                path: path,
              );
              await repo.updateModel(updated);

              // Reload recognition model
              await ref.read(recognitionServiceProvider).reloadModel();

              if (context.mounted) {
                Navigator.pop(context);
                setState(() {
                  _modelsFuture = _loadModels();
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.tr('model.downloadComplete'))),
                );
              }
            }
          }, onError: (e) async {
            sub?.cancel();
            if (context.mounted) {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        '${context.tr('model.downloadFailedPrefix')}: $e')),
              );
            }
          });
        }

        startDownload();

        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: Text('${context.tr('model.downloadModel')}: ${model.name}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: LinearProgressIndicator(value: progress),
                ),
                const SizedBox(height: 8),
                Text('${(progress * 100).toStringAsFixed(0)}%'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  // Cancel download
                  await sub?.cancel();
                  // Attempt to clean up partial files
                  try {
                    await manager.deleteModel(model.modelId);
                  } catch (_) {}
                  if (context.mounted) Navigator.pop(context);
                },
                child: Text(context.tr('common.cancel')),
              ),
            ],
          );
        });
      },
    );
  }

  void _handleDelete(ModelMetadata model) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('model.deleteModel')),
        content: Text(context.tr('model.deleteModelConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.tr('common.cancel')),
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
                SnackBar(content: Text(context.tr('model.modelDeleted'))),
              );
            },
            child: Text(context.tr('common.delete')),
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
        SnackBar(content: Text(context.tr('model.downloadFirst'))),
      );
      return;
    }

    await ref.read(settingsProvider.notifier).setCurrentModelId(model.modelId);
    await ref.read(settingsProvider.notifier).setAutoModelSelect(false);
    navigator.pop(model.modelId);
  }

  // Removed unused simulate download helper; real downloads are handled
  // by `_handleDownload` which uses `ModelManagerService`.
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
    final theme = Theme.of(context);
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
                        '${context.tr('common.version')}: ${model.version}',
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
                  position: PopupMenuPosition.under,
                  offset: const Offset(0, 8),
                  elevation: 10,
                  color: theme.colorScheme.surfaceContainerHighest,
                  surfaceTintColor: theme.colorScheme.surfaceTint,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
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
                      items.add(PopupMenuItem(
                        value: 'select',
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline_rounded,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Text(context.tr('common.setAsCurrent')),
                          ],
                        ),
                      ));
                    }

                    // Add "Download" option if not downloaded
                    if (!model.isDownloaded) {
                      items.add(PopupMenuItem(
                        value: 'download',
                        child: Row(
                          children: [
                            Icon(
                              Icons.download_rounded,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Text(context.tr('common.download')),
                          ],
                        ),
                      ));
                    }

                    // Add "Delete" option if downloaded
                    if (model.isDownloaded) {
                      items.add(PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: theme.colorScheme.error,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              context.tr('common.delete'),
                              style: TextStyle(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ],
                        ),
                      ));
                    }

                    return items;
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh,
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.more_horiz_rounded,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
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
                  _getPerformanceLabel(context, model.accuracyTag),
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

  String _getPerformanceLabel(BuildContext context, String accuracyTag) {
    if (accuracyTag.toLowerCase().contains('speed') ||
        accuracyTag.toLowerCase().contains('latency')) {
      return context.tr('model.lowLatency');
    } else if (accuracyTag.toLowerCase().contains('accuracy')) {
      return context.tr('model.highAccuracy');
    }
    return accuracyTag;
  }
}
