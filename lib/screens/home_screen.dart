import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../widgets/recording_overlay.dart';
import '../widgets/todo_item_card.dart';
import '../widgets/floating_action_toolbar.dart';
import '../services/model_manager_service.dart';
import '../services/recognition_service.dart';
import '../models/todo_item.dart';

/// Main home screen displaying the todo list
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isModelReady = false;
  bool _isCheckingModel = true;

  @override
  void initState() {
    super.initState();
    _checkModelStatus();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('AudioNotes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              // TODO: Navigate to settings
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Todo list - only rebuilds when todos change
          const _TodoListContent(),

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
  const _TodoListContent();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todosAsync = ref.watch(todoListProvider);

    return todosAsync.when(
      data: (todos) {
        if (todos.isEmpty) {
          return _buildEmptyState();
        }

        // Separate pending and completed todos
        final pendingTodos =
            todos.where((todo) => todo.status == TodoStatus.pending).toList();
        final completedTodos =
            todos.where((todo) => todo.status == TodoStatus.completed).toList();
        final entries = _buildEntries(pendingTodos, completedTodos);

        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 96),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final entry = entries[index];
                    if (entry.isHeader) {
                      return _SectionHeader(
                        title: entry.title,
                        color: entry.section == TodoStatus.pending
                            ? Theme.of(context).primaryColor
                            : Colors.grey[600]!,
                      );
                    }

                    final todo = entry.todo!;
                    return TodoItemCard(
                      key: ValueKey(todo.id),
                      todo: todo,
                    );
                  },
                  childCount: entries.length,
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, stackTrace) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              '加载失败',
              style: TextStyle(
                fontSize: 20,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.mic_none,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            '暂无笔记',
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '点击麦克风开始录音',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }
}

class _TodoListEntry {
  final String key;
  final TodoItem? todo;
  final TodoStatus? section;
  final String title;

  const _TodoListEntry._({
    required this.key,
    required this.title,
    this.todo,
    this.section,
  });

  factory _TodoListEntry.header(String title, TodoStatus section) {
    return _TodoListEntry._(
      key: 'header-${section.name}',
      title: title,
      section: section,
    );
  }

  factory _TodoListEntry.todo(TodoItem todo) {
    return _TodoListEntry._(
      key: 'todo-${todo.id}',
      title: todo.text,
      todo: todo,
      section: todo.status,
    );
  }

  bool get isHeader => todo == null;
}

List<_TodoListEntry> _buildEntries(
  List<TodoItem> pendingTodos,
  List<TodoItem> completedTodos,
) {
  final entries = <_TodoListEntry>[];

  if (pendingTodos.isNotEmpty) {
    entries.add(_TodoListEntry.header('未完成', TodoStatus.pending));
    entries.addAll(pendingTodos.map(_TodoListEntry.todo));
  }

  if (completedTodos.isNotEmpty) {
    entries.add(_TodoListEntry.header('已完成', TodoStatus.completed));
    entries.addAll(completedTodos.map(_TodoListEntry.todo));
  }

  return entries;
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;

  const _SectionHeader({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: color,
        ),
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
