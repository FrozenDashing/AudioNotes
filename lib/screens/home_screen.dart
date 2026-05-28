import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../models/todo_item.dart';
// category model no longer needed here (groups derived via providers)
import '../widgets/recording_overlay.dart';
import '../widgets/todo_group_section.dart';
import '../widgets/floating_action_toolbar.dart';
import 'settings_screen.dart';
import '../services/model_manager_service.dart';
import '../services/recognition_service.dart';
import '../models/todo_sort.dart';
import '../models/todo_query_options.dart';
import '../providers/settings_provider.dart';

enum _HomeMenuAction { sort, toggleSelection }

/// Main home screen displaying the todo list
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isModelReady = false;
  bool _isCheckingModel = true;
  Map<String, int> _groupOrderMap = {};

  void _showSortSheet() {
    final settings = ref.read(settingsProvider);
    var selectedField = settings.todoSortField;
    var selectedDirection = settings.todoSortDirection;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '排序',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  '排序字段',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: RadioGroup<TodoSortField>(
                    groupValue: selectedField,
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      selectedField = value;
                      (ctx as Element).markNeedsBuild();
                    },
                    child: Column(
                      children: [
                        const RadioListTile<TodoSortField>(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          title: Text('手动顺序'),
                          value: TodoSortField.manual,
                        ),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: theme.colorScheme.outlineVariant,
                        ),
                        const RadioListTile<TodoSortField>(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          title: Text('创建时间'),
                          value: TodoSortField.createdAt,
                        ),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: theme.colorScheme.outlineVariant,
                        ),
                        const RadioListTile<TodoSortField>(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          title: Text('截止时间'),
                          value: TodoSortField.dueAt,
                        ),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: theme.colorScheme.outlineVariant,
                        ),
                        const RadioListTile<TodoSortField>(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          title: Text('优先级'),
                          value: TodoSortField.priority,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '排序方向',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: RadioGroup<SortDirection>(
                    groupValue: selectedDirection,
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      selectedDirection = value;
                      (ctx as Element).markNeedsBuild();
                    },
                    child: Column(
                      children: [
                        const RadioListTile<SortDirection>(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          title: Text('升序'),
                          value: SortDirection.asc,
                        ),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: theme.colorScheme.outlineVariant,
                        ),
                        const RadioListTile<SortDirection>(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          title: Text('降序'),
                          value: SortDirection.desc,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final navigator = Navigator.of(context);

                          // persist settings
                          await ref
                              .read(settingsProvider.notifier)
                              .setTodoSortField(selectedField);
                          await ref
                              .read(settingsProvider.notifier)
                              .setTodoSortDirection(selectedDirection);

                          // apply to list
                          final options = TodoQueryOptions(
                            sortField: selectedField,
                            direction: selectedDirection,
                          );
                          navigator.pop();
                          await ref
                              .read(todoListProvider.notifier)
                              .setQueryOptions(options);
                        },
                        child: const Text('应用'),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _checkModelStatus();
    unawaited(_loadGroupOrder());
  }

  /// Update stored group order map safely within this State.
  void updateGroupOrderMap(Map<String, int> newMap) {
    if (!mounted) return;
    setState(() {
      _groupOrderMap = newMap;
    });
    // Also update global provider so group order is used when building groups
    try {
      ref.read(groupOrderMapProvider.notifier).setMap(newMap);
    } catch (_) {
      // ignore if provider unavailable
    }
  }

  Future<void> _loadGroupOrder() async {
    final orderMap =
        await ref.read(todoGroupingServiceProvider).loadGroupOrderMap();
    if (!mounted) {
      return;
    }
    setState(() {
      _groupOrderMap = orderMap;
    });
    // set global provider as well
    try {
      ref.read(groupOrderMapProvider.notifier).setMap(orderMap);
    } catch (_) {
      // ignore
    }
  }

  Future<void> _checkModelStatus() async {
    setState(() => _isCheckingModel = true);

    final modelManager = ref.read(modelManagerServiceProvider);

    // Check if small Chinese model is downloaded (faster to download)
    final hasSmallModel =
        await modelManager.isModelDownloaded('vosk-model-small-cn-0.22');
    final hasLargeModel =
        await modelManager.isModelDownloaded('vosk-model-cn-0.22');

    setState(() {
      _isModelReady = hasSmallModel || hasLargeModel;
      _isCheckingModel = false;
    });

    if (!_isModelReady) {
      // Show model download dialog after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _showModelDownloadDialog();
        }
      });
    }
  }

  void _showModelDownloadDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _ModelDownloadDialog(
        modelManager: ref.read(modelManagerServiceProvider),
        recognitionService: ref.read(recognitionServiceProvider),
        onModelReady: () {
          setState(() => _isModelReady = true);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupOrderMap = _groupOrderMap;
    final todoNotifier = ref.read(todoListProvider.notifier);
    final isSelectionMode = todoNotifier.isSelectionMode;
    final todos = ref.watch(todoListProvider).maybeWhen(
          data: (items) => items,
          orElse: () => const <TodoItem>[],
        );
    final allSelected = isSelectionMode &&
        todos.isNotEmpty &&
        todoNotifier.selectedIds.length == todos.length;

    return Scaffold(
      appBar: AppBar(
        leading: isSelectionMode
            ? IconButton(
                icon: Icon(allSelected ? Icons.check_box : Icons.select_all),
                tooltip: allSelected ? '全不选' : '全选',
                onPressed: () {
                  if (allSelected) {
                    todoNotifier.clearSelection();
                  } else {
                    todoNotifier.selectAllTodos();
                  }
                },
              )
            : PopupMenuButton<_HomeMenuAction>(
                icon: const Icon(Icons.more_horiz),
                tooltip: '更多',
                position: PopupMenuPosition.under,
                offset: const Offset(0, 8),
                elevation: 10,
                color: theme.colorScheme.surfaceContainerHighest,
                surfaceTintColor: theme.colorScheme.surfaceTint,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onSelected: (action) {
                  switch (action) {
                    case _HomeMenuAction.sort:
                      _showSortSheet();
                      break;
                    case _HomeMenuAction.toggleSelection:
                      todoNotifier.enableSelectionMode();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: _HomeMenuAction.sort,
                    child: Row(
                      children: [
                        Icon(
                          Icons.sort_rounded,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        const Text('排序'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: _HomeMenuAction.toggleSelection,
                    child: Row(
                      children: [
                        Icon(
                          Icons.checklist_rounded,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        const Text('选择'),
                      ],
                    ),
                  ),
                ],
              ),
        actions: [
          if (isSelectionMode)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: '退出选择',
              onPressed: () => todoNotifier.disableSelectionMode(),
            )
          else
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                // Navigate to settings screen
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SettingsScreen(),
                  ),
                );
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          // Todo list - only rebuilds when todos change
          _TodoListContent(
            groupOrderMap: groupOrderMap,
            onGroupOrderChanged: updateGroupOrderMap,
          ),

          // Recording overlay - only rebuilds when recording state or partial text changes
          const _RecordingOverlayWrapper(),

          // ✅ Floating action toolbar for batch operations
          const FloatingActionToolbar(),

          // Model not ready overlay
          if (!_isModelReady && !_isCheckingModel)
            Container(
              color: Colors.black.withValues(alpha: 0.7),
              child: Center(
                child: Card(
                  margin: const EdgeInsets.all(32),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.download_for_offline,
                          size: 64,
                          color: Colors.blue,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '语音包未下载',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '需要下载中文语音包才能使用语音识别功能',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: _showModelDownloadDialog,
                          icon: const Icon(Icons.download),
                          label: const Text('下载语音包'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: _RecordingFAB(
        isModelReady: _isModelReady,
        onModelNotReady: _showModelDownloadDialog,
      ),
    );
  }
}

/// Todo list content - only rebuilds when todos change
class _TodoListContent extends ConsumerWidget {
  final Map<String, int> groupOrderMap;
  final void Function(Map<String, int> map) onGroupOrderChanged;

  const _TodoListContent({
    required this.groupOrderMap,
    required this.onGroupOrderChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Use derived providers to let each group rebuild independently when its items change.
    final groupKeys = ref.watch(todoGroupKeysProvider);
    final settings = ref.watch(settingsProvider);
    final isManualSortEnabled = settings.todoSortField == TodoSortField.manual;

    if (groupKeys.isEmpty) {
      return _buildEmptyState(context);
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.only(bottom: 96),
      buildDefaultDragHandles: false,
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final t = Curves.easeOut.transform(animation.value);
            return Transform.scale(
              scale: 1.0 + (0.015 * t),
              child: Material(
                elevation: 8 + (4 * t),
                color: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                clipBehavior: Clip.antiAlias,
                child: child,
              ),
            );
          },
        );
      },
      itemCount: groupKeys.length,
      onReorder: (oldIndex, newIndex) async {
        if (oldIndex == newIndex) {
          return;
        }
        final groupingService = ref.read(todoGroupingServiceProvider);
        final previousOrderMap = Map<String, int>.from(groupOrderMap);
        // compute new order of keys
        final orderedKeys = List<String>.from(groupKeys);
        if (newIndex > oldIndex) newIndex -= 1;
        final movedKey = orderedKeys.removeAt(oldIndex);
        orderedKeys.insert(newIndex, movedKey);
        final updatedOrderMap = <String, int>{};
        for (var index = 0; index < orderedKeys.length; index++) {
          updatedOrderMap[orderedKeys[index]] = index;
        }
        // Optimistically update first to avoid visible snap-back/flicker.
        onGroupOrderChanged(updatedOrderMap);
        try {
          await groupingService.saveGroupOrderMap(updatedOrderMap);
        } catch (_) {
          onGroupOrderChanged(previousOrderMap);
        }
      },
      itemBuilder: (context, index) {
        final key = groupKeys[index];
        return Consumer(
          key: ValueKey(key),
          builder: (context, ref, _) {
            final group = ref.watch(todoGroupProvider(key));
            if (group == null) return const SizedBox.shrink();
            return TodoGroupSection(
              key: ValueKey(group.groupKey),
              group: group,
              groupIndex: index,
              isManualSortEnabled: isManualSortEnabled,
              onMoveItemToGroup: (
                todoId,
                targetCategoryId,
                targetIndex, {
                sourceGroupKey,
                sourceIndex,
              }) async {
                await ref
                    .read(todoListProvider.notifier)
                    .moveTodoToCategoryAtIndex(
                      todoId,
                      targetCategoryId,
                      targetIndex,
                      sourceGroupKey: sourceGroupKey,
                      sourceIndex: sourceIndex,
                    );
              },
              onReorderWithinGroup: (oldIndex, newIndex) async {
                await ref.read(todoListProvider.notifier).reorderTodosInGroup(
                      group.items,
                      oldIndex,
                      newIndex,
                    );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.mic_none,
            size: 80,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无笔记',
            style: TextStyle(
              fontSize: 20,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击麦克风开始录音',
            style: TextStyle(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// Recording overlay wrapper - only rebuilds when recording state or partial text changes
class _RecordingOverlayWrapper extends ConsumerWidget {
  const _RecordingOverlayWrapper();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordingState = ref.watch(recordingStateProvider);
    final partialText = ref.watch(partialTranscriptProvider);

    if (recordingState == RecordingState.recording ||
        recordingState == RecordingState.recognizing) {
      return RecordingOverlay(
        isProcessing: recordingState == RecordingState.recognizing,
        partialText: partialText,
      );
    }

    return const SizedBox.shrink();
  }
}

/// Recording FAB wrapper - only rebuilds when recording state changes
class _RecordingFAB extends ConsumerWidget {
  final bool isModelReady;
  final VoidCallback? onModelNotReady;

  const _RecordingFAB({
    required this.isModelReady,
    this.onModelNotReady,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordingState = ref.watch(recordingStateProvider);

    return FloatingActionButton.extended(
      onPressed: _getOnPressed(recordingState, ref, context),
      label: Text(
        recordingState == RecordingState.idle
            ? (isModelReady ? '录音' : '请先下载语音包')
            : recordingState == RecordingState.recording
                ? '停止'
                : '处理中...',
      ),
      icon: Icon(
        recordingState == RecordingState.idle ? Icons.mic : Icons.stop,
      ),
      backgroundColor: !isModelReady && recordingState == RecordingState.idle
          ? Colors.orange
          : recordingState == RecordingState.recording
              ? Colors.red
              : Theme.of(context).primaryColor,
    );
  }

  VoidCallback? _getOnPressed(
      RecordingState recordingState, WidgetRef ref, BuildContext context) {
    if (recordingState == RecordingState.idle) {
      // Idle state: can start recording
      return () =>
          _startRecording(ref.read(recordingStateProvider.notifier), context);
    } else if (recordingState == RecordingState.recording) {
      // Recording state: can stop recording
      return () => _stopRecording(ref.read(recordingStateProvider.notifier));
    }
    // Processing state: disable button
    return null;
  }

  void _startRecording(RecordingNotifier notifier, BuildContext context) {
    if (!isModelReady) {
      // Call the callback to show download dialog
      onModelNotReady?.call();
      return;
    }

    // Async operation, but we don't await to keep UI responsive
    notifier.start().catchError((error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('开始录音失败: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  void _stopRecording(RecordingNotifier notifier) {
    // Async operation, but we don't await to keep UI responsive
    notifier.stop().catchError((error) {
      print('Stop recording error: $error');
    });
  }
}

/// Dialog for downloading Vosk model
class _ModelDownloadDialog extends StatefulWidget {
  final ModelManagerService modelManager;
  final RecognitionService recognitionService;
  final VoidCallback onModelReady;

  const _ModelDownloadDialog({
    required this.modelManager,
    required this.recognitionService,
    required this.onModelReady,
  });

  @override
  State<_ModelDownloadDialog> createState() => _ModelDownloadDialogState();
}

class _ModelDownloadDialogState extends State<_ModelDownloadDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String _status = '';
  String? _error;

  Future<void> _downloadModel() async {
    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _error = null;
    });

    try {
      // Prefer small model for faster download (~45MB vs ~1.8GB)
      final model = VoskModel.chineseSmall();

      setState(() {
        _status = '正在下载中文语音包 (${model.sizeMB} MB)...';
      });

      await for (final progress in widget.modelManager.downloadModel(model)) {
        setState(() {
          _progress = progress;
          if (progress < 0.7) {
            _status = '下载中... ${(progress * 100).toStringAsFixed(0)}%';
          } else if (progress < 0.95) {
            _status = '解压中... ${(progress * 100).toStringAsFixed(0)}%';
          } else {
            _status = '完成!';
          }
        });
      }

      setState(() {
        _status = '语音包已就绪！';
      });

      // Reload the actual recognition plugin so newly downloaded models are used immediately
      await widget.recognitionService.reloadModel();

      // Wait a moment then close dialog
      await Future.delayed(const Duration(seconds: 1));

      widget.onModelReady();

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      setState(() {
        _error = '下载失败: $e';
        _isDownloading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('下载语音包'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '需要下载中文语音包才能实现离线语音识别。',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text(
              '• 小型模型: ~45 MB (推荐)',
              style: TextStyle(fontSize: 13),
            ),
            const Text(
              '• 大型模型: ~1.8 GB (更高准确率)',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            if (_isDownloading || _progress > 0) ...[
              LinearProgressIndicator(value: _progress),
              const SizedBox(height: 8),
              Text(
                _status,
                style: const TextStyle(fontSize: 13),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (!_isDownloading)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
        if (!_isDownloading)
          ElevatedButton.icon(
            onPressed: _downloadModel,
            icon: const Icon(Icons.download),
            label: const Text('下载小型模型'),
          ),
        if (_isDownloading) const CircularProgressIndicator(),
      ],
    );
  }
}
