import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Added for HapticFeedback
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_i18n.dart';
import '../providers/app_providers.dart';
import '../models/todo_item.dart';
// category model no longer needed here (groups derived via providers)
import '../widgets/recording_overlay.dart';
import '../widgets/todo_group_section.dart';
import '../widgets/floating_action_toolbar.dart';
import 'settings_screen.dart';
import 'trash_screen.dart';
import '../services/model_manager_service.dart';
import '../services/recognition_service.dart';
import '../models/todo_sort.dart';
import '../models/todo_query_options.dart';
import '../providers/settings_provider.dart';
import '../utils/motion.dart';

enum _HomeMenuAction { sort, toggleSelection, trash }

/// Main home screen displaying the todo list
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isModelReady = false;
  bool _isCheckingModel = true;

  void _showSortSheet() {
    final settings = ref.read(settingsProvider);
    var selectedField = settings.todoSortField;
    var selectedDirection = settings.todoSortDirection;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return motionEntrance(
          ctx,
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('home.sort.title'),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr('home.sort.field'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: theme.colorScheme.outlineVariant),
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
                          RadioListTile<TodoSortField>(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                            title:
                                Text(context.tr('settings.todo.sort.manual')),
                            value: TodoSortField.manual,
                          ),
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: theme.colorScheme.outlineVariant,
                          ),
                          RadioListTile<TodoSortField>(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                            title: Text(
                                context.tr('settings.todo.sort.createdAt')),
                            value: TodoSortField.createdAt,
                          ),
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: theme.colorScheme.outlineVariant,
                          ),
                          RadioListTile<TodoSortField>(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                            title: Text(context.tr('settings.todo.sort.dueAt')),
                            value: TodoSortField.dueAt,
                          ),
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: theme.colorScheme.outlineVariant,
                          ),
                          RadioListTile<TodoSortField>(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                            title:
                                Text(context.tr('settings.todo.sort.priority')),
                            value: TodoSortField.priority,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    context.tr('home.sort.direction'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: theme.colorScheme.outlineVariant),
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
                          RadioListTile<SortDirection>(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                            title: Text(context.tr('settings.todo.sort.asc')),
                            value: SortDirection.asc,
                          ),
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: theme.colorScheme.outlineVariant,
                          ),
                          RadioListTile<SortDirection>(
                            dense: true,
                            visualDensity: VisualDensity.compact,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                            ),
                            title: Text(context.tr('settings.todo.sort.desc')),
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
                          child: Text(context.tr('home.sort.apply')),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ),
          duration: MotionTokens.page,
          slideY: 0.06,
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _checkModelStatus();
  }

  /// Update stored group order map by writing to the global provider.
  void updateGroupOrderMap(Map<String, int> newMap) {
    try {
      ref.read(groupOrderMapProvider.notifier).setMap(newMap);
    } catch (e) {
      debugPrint('Failed to update group order provider: $e');
    }
  }

  Future<void> _checkModelStatus() async {
    setState(() => _isCheckingModel = true);

    final modelManager = ref.read(modelManagerServiceProvider);

    // Check if small Chinese model is downloaded (faster to download)
    final hasSmallModel =
        await modelManager.isModelDownloaded(VoskModel.chineseSmallModelName);
    final hasLargeModel =
        await modelManager.isModelDownloaded(VoskModel.chineseLarge().name);

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
      builder: (context) => motionEntrance(
        context,
        _ModelDownloadDialog(
          modelManager: ref.read(modelManagerServiceProvider),
          recognitionService: ref.read(recognitionServiceProvider),
          onModelReady: () {
            setState(() => _isModelReady = true);
          },
        ),
        duration: MotionTokens.page,
        scaleBegin: 0.96,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final groupOrderMap = ref.watch(groupOrderMapProvider);
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
                tooltip: allSelected
                    ? context.tr('home.selection.clearAll')
                    : context.tr('home.selection.selectAll'),
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
                tooltip: context.tr('home.menu.more'),
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
                    case _HomeMenuAction.trash:
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TrashScreen(),
                        ),
                      );
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
                        Text(context.tr('home.sort.title')),
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
                        Text(context.tr('home.selection.title')),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: _HomeMenuAction.trash,
                    child: Row(
                      children: [
                        Icon(
                          Icons.delete_outline,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 10),
                        Text(context.tr('home.menu.trash')),
                      ],
                    ),
                  ),
                ],
              ),
        actions: [
          if (isSelectionMode)
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: context.tr('home.selection.exit'),
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

          // Floating action toolbar for batch operations
          // ignore: prefer_const_constructors — must not be const to rebuild on selection change
          FloatingActionToolbar(),

          // Model not ready overlay
          if (!_isModelReady && !_isCheckingModel)
            motionEntrance(
              context,
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
                          Text(
                            context.tr('home.model.notDownloadedTitle'),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.tr('home.model.notDownloadedSubtitle'),
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
                            label: Text(context.tr('home.model.downloadPack')),
                          ),
                        ],
                      ),
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
      return _buildEmptyState(context, ref);
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
        final groupOrderNotifier = ref.read(groupOrderMapProvider.notifier);
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
          await groupOrderNotifier.saveMap(updatedOrderMap);
        } catch (e) {
          debugPrint('Failed to save group order map: $e');
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

  Widget _buildEmptyState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Builder(builder: (ctx) {
            final settings = ref.watch(settingsProvider);
            final isQuick = settings.enableQuickTextTodo;
            return Icon(
              isQuick ? Icons.sticky_note_2 : Icons.mic_none,
              size: 80,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            );
          }),
          const SizedBox(height: 16),
          Builder(builder: (ctx) {
            final settings = ref.watch(settingsProvider);
            final isQuick = settings.enableQuickTextTodo;
            return Text(
              isQuick
                  ? ctx.tr('home.empty.quickTitle')
                  : ctx.tr('home.empty.title'),
              style: TextStyle(
                fontSize: 20,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            );
          }),
          const SizedBox(height: 8),
          Builder(builder: (ctx) {
            final settings = ref.watch(settingsProvider);
            final isQuick = settings.enableQuickTextTodo;
            return Text(
              isQuick
                  ? ctx.tr('home.empty.quickSubtitle')
                  : ctx.tr('home.empty.subtitle'),
              style: TextStyle(
                fontSize: 14,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            );
          }),
        ],
      ),
    );
  }
}

/// Recording overlay wrapper - only rebuilds when recording state changes
class _RecordingOverlayWrapper extends ConsumerWidget {
  const _RecordingOverlayWrapper();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordingState = ref.watch(recordingStateProvider);

    if (recordingState == RecordingState.recording ||
        recordingState == RecordingState.recognizing) {
      return RecordingOverlay(
        isProcessing: recordingState == RecordingState.recognizing,
      );
    }

    return const SizedBox.shrink();
  }
}

/// Recording FAB wrapper - only rebuilds when recording state changes
class _RecordingFAB extends ConsumerStatefulWidget {
  final bool isModelReady;
  final VoidCallback? onModelNotReady;

  const _RecordingFAB({
    required this.isModelReady,
    this.onModelNotReady,
  });

  @override
  ConsumerState<_RecordingFAB> createState() => _RecordingFABState();
}

class _RecordingFABState extends ConsumerState<_RecordingFAB>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _scaleController.forward();
    HapticFeedback.lightImpact();
  }

  void _onTapUp(TapUpDetails details) {
    _scaleController.reverse();
  }

  void _onTapCancel() {
    _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final recordingState = ref.watch(recordingStateProvider);
    final settings = ref.watch(settingsProvider);

    final theme = Theme.of(context);
    final isLightTheme = theme.brightness == Brightness.light;
    final fab = FloatingActionButton.extended(
      onPressed: settings.enableQuickTextTodo
          ? () => _openQuickTextDialog(context)
          : _getOnPressed(recordingState, ref, context),
      label: Text(
        settings.enableQuickTextTodo
            ? context.tr('home.quickTodo')
            : (recordingState == RecordingState.idle
                ? (widget.isModelReady
                    ? context.tr('home.record.start')
                    : context.tr('home.model.downloadFirst'))
                : recordingState == RecordingState.recording
                    ? context.tr('home.record.stop')
                    : context.tr('home.record.processing')),
      ),
      icon: Icon(
        settings.enableQuickTextTodo
            ? Icons.edit_outlined
            : (recordingState == RecordingState.idle ? Icons.mic : Icons.stop),
      ),
      backgroundColor:
          !widget.isModelReady && recordingState == RecordingState.idle
              ? Colors.orange
              : recordingState == RecordingState.recording
                  ? Colors.red
                  : (isLightTheme
                      ? theme.colorScheme.surfaceContainerHighest
                      : theme.colorScheme.primary),
      foregroundColor:
          !widget.isModelReady && recordingState == RecordingState.idle
              ? Colors.white
              : recordingState == RecordingState.recording
                  ? Colors.white
                  : (isLightTheme
                      ? theme.colorScheme.onSurfaceVariant
                      : theme.colorScheme.onPrimary),
    );

    // Tap-to-scale feedback on every press, no idle bounce
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: settings.enableQuickTextTodo
          ? () => _openQuickTextDialog(context)
          : null,
      onLongPress: settings.enableQuickTextTodo
          ? () => _startRecording(
              ref.read(recordingStateProvider.notifier), context)
          : null,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: fab,
      ),
    );
  }

  Future<void> _openQuickTextDialog(BuildContext context) async {
    final controller = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final theme = Theme.of(context);

    final successMsg = context.tr('home.quickTodoCreated');
    final failMsgPrefix = context.tr('home.quickTodoCreateFailed');

    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
          ),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ctx.tr('home.quickTodoTitle'),
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: controller,
                  autofocus: true,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    hintText: ctx.tr('home.quickTodoHint'),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return ctx.tr('home.quickTodoValidate');
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) {
                    if (formKey.currentState?.validate() ?? false) {
                      Navigator.of(ctx).pop(controller.text);
                    }
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text(ctx.tr('common.cancel')),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () {
                        if (formKey.currentState?.validate() ?? false) {
                          Navigator.of(ctx).pop(controller.text);
                        }
                      },
                      child: Text(ctx.tr('home.quickTodoCreate')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (text == null) return;

    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    await _createQuickTextTodo(trimmed, successMsg, failMsgPrefix);
  }

  Future<void> _createQuickTextTodo(
      String text, String successMsg, String failMsgPrefix) async {
    try {
      final priority = ref.read(settingsProvider).defaultTodoPriority;
      final repo = ref.read(todoRepositoryProvider);
      await repo.insertTextTodo(text: text, priority: priority);
      await ref.read(todoListProvider.notifier).loadTodos();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMsg)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$failMsgPrefix: $e')),
      );
    }
  }

  VoidCallback? _getOnPressed(
      RecordingState recordingState, WidgetRef ref, BuildContext context) {
    if (recordingState == RecordingState.idle) {
      return () =>
          _startRecording(ref.read(recordingStateProvider.notifier), context);
    } else if (recordingState == RecordingState.recording) {
      return () => _stopRecording(ref.read(recordingStateProvider.notifier));
    }
    return null;
  }

  void _startRecording(RecordingNotifier notifier, BuildContext context) {
    if (!widget.isModelReady) {
      widget.onModelNotReady?.call();
      return;
    }

    // Async operation, but we don't await to keep UI responsive
    _scaleController.reverse();
    notifier.start().catchError((error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.tr('home.record.startFailed',
                  params: {'error': error.toString()}),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    });
  }

  void _stopRecording(RecordingNotifier notifier) {
    _scaleController.reverse();
    // Async operation, but we don't await to keep UI responsive
    notifier.stop().catchError((error) {
      debugPrint('Stop recording error: $error');
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
        _status = context.tr(
          'home.model.downloadingPack',
          params: {'size': model.sizeMB.toStringAsFixed(0)},
        );
      });

      await for (final progress in widget.modelManager.downloadModel(model)) {
        setState(() {
          _progress = progress;
          if (progress < 0.7) {
            _status = context.tr(
              'home.model.downloadingProgress',
              params: {'percent': (progress * 100).toStringAsFixed(0)},
            );
          } else if (progress < 0.95) {
            _status = context.tr(
              'home.model.extractingProgress',
              params: {'percent': (progress * 100).toStringAsFixed(0)},
            );
          } else {
            _status = context.tr('home.model.done');
          }
        });
      }

      setState(() {
        _status = context.tr('home.model.ready');
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
        _error = context
            .tr('home.model.downloadFailed', params: {'error': e.toString()});
        _isDownloading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.tr('home.model.downloadPack')),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.tr('home.model.dialogIntro'),
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('home.model.smallModelHint'),
              style: const TextStyle(fontSize: 13),
            ),
            Text(
              context.tr('home.model.largeModelHint'),
              style: const TextStyle(fontSize: 13),
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
            child: Text(context.tr('common.cancel')),
          ),
        if (!_isDownloading)
          ElevatedButton.icon(
            onPressed: _downloadModel,
            icon: const Icon(Icons.download),
            label: Text(context.tr('home.model.downloadSmallModel')),
          ),
        if (_isDownloading) const CircularProgressIndicator(),
      ],
    );
  }
}
