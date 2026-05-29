import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_i18n.dart';

import '../models/category.dart';
import '../models/todo_group.dart';
import '../models/todo_item.dart';
import '../providers/app_providers.dart';
import '../services/todo_grouping_service.dart';
import 'todo_item_card.dart';

/// Category shell that renders a todo group.
class TodoGroupSection extends ConsumerStatefulWidget {
  final TodoGroup group;
  final int groupIndex;
  final bool isManualSortEnabled;
  final Future<void> Function(
    String todoId,
    String? targetCategoryId,
    int targetIndex, {
    String? sourceGroupKey,
    int? sourceIndex,
  }) onMoveItemToGroup;
  final Future<void> Function(int oldIndex, int newIndex) onReorderWithinGroup;

  const TodoGroupSection({
    super.key,
    required this.group,
    required this.groupIndex,
    required this.isManualSortEnabled,
    required this.onMoveItemToGroup,
    required this.onReorderWithinGroup,
  });

  @override
  ConsumerState<TodoGroupSection> createState() => _TodoGroupSectionState();
}

class _TodoGroupSectionState extends ConsumerState<TodoGroupSection> {
  bool _isExpanded = true;
  Timer? _saveTimer;

  static const List<Color> _categoryColors = [
    Color(0xFFE57373),
    Color(0xFFF06292),
    Color(0xFFBA68C8),
    Color(0xFF9575CD),
    Color(0xFF7986CB),
    Color(0xFF64B5F6),
    Color(0xFF4FC3F7),
    Color(0xFF4DD0E1),
    Color(0xFF4DB6AC),
    Color(0xFF81C784),
    Color(0xFFFFB74D),
    Color(0xFFA1887F),
  ];

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.group.isExpanded;
    unawaited(_loadPersistedExpandedState());
  }

  @override
  void didUpdateWidget(covariant TodoGroupSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.group.groupKey != widget.group.groupKey) {
      _isExpanded = widget.group.isExpanded;
      unawaited(_loadPersistedExpandedState());
    }
  }

  Future<void> _loadPersistedExpandedState() async {
    try {
      final svc = ref.read(todoGroupingServiceProvider);
      final map = await svc.loadExpandedMap();
      final persisted = map[widget.group.groupKey];
      if (!mounted || persisted == null || persisted == _isExpanded) {
        return;
      }
      setState(() => _isExpanded = persisted);
    } catch (_) {
      // Ignore persistence errors and keep UI responsive.
    }
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    super.dispose();
  }

  void _toggleExpanded() {
    final newExpanded = !_isExpanded;
    setState(() => _isExpanded = newExpanded);

    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 300), () async {
      try {
        final svc = ref.read(todoGroupingServiceProvider);
        final map = await svc.loadExpandedMap();
        final updated = {...map, widget.group.groupKey: _isExpanded};
        await svc.saveExpandedMap(updated);
      } catch (_) {
        // ignore errors; do not block UI
      }
    });
  }

  Future<void> _showCategoryActions() async {
    if (widget.group.categoryId == null || widget.group.isCompletedAggregate) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(context.tr('category.editTitle')),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _editCategory();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: Text(context.tr('category.deleteTitle'),
                    style: const TextStyle(color: Colors.red)),
                subtitle: Text(context.tr('category.deleteSubtitle')),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _deleteCategory();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editCategory() async {
    final categories = await ref.read(categoryListProvider.future);
    if (!mounted) {
      return;
    }
    final category = categories.firstWhere(
      (item) => item.id == widget.group.categoryId,
      orElse: () => Category(
        id: widget.group.categoryId!,
        name: widget.group.title,
        color: widget.group.color,
      ),
    );

    final nameController = TextEditingController(text: category.name);
    var selectedColor = category.color ?? _categoryColors.first.toARGB32();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(context.tr('category.editTitle')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: context.tr('category.nameLabel'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categoryColors.map((color) {
                        final isSelected = selectedColor == color.toARGB32();
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              selectedColor = color.toARGB32();
                            });
                          },
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: Colors.white, width: 2)
                                  : null,
                            ),
                          ),
                        );
                      }).toList(growable: false),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(context.tr('common.cancel')),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(context.tr('common.save')),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final newName = nameController.text.trim();
    if (newName.isEmpty) {
      return;
    }

    await ref.read(categoryRepositoryProvider).updateCategory(
          category.copyWith(name: newName, color: selectedColor),
        );
    ref.invalidate(categoryListProvider);
  }

  Future<void> _deleteCategory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.tr('category.deleteTitle')),
          content: Text(context.tr('category.deleteConfirmWithName',
              params: {'name': widget.group.title})),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.tr('common.cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(context.tr('common.delete')),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await ref
        .read(categoryRepositoryProvider)
        .deleteCategory(widget.group.categoryId!);
    await ref.read(todoListProvider.notifier).loadTodos();
    ref.invalidate(categoryListProvider);
  }

  String _noteCountLabel(int count) {
    return context.tr('group.noteCount', params: {'count': count.toString()});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final headerBorderRadius = BorderRadius.vertical(
      top: const Radius.circular(20),
      bottom: Radius.circular(_isExpanded ? 0 : 20),
    );
    final accentColor = widget.group.isCompletedAggregate
        ? theme.colorScheme.outline
        : (widget.group.color == null
            ? theme.colorScheme.primary
            : Color(widget.group.color!));
    final groupTextColor = widget.group.isCompletedAggregate
        ? theme.colorScheme.onSurfaceVariant
        : theme.colorScheme.onSurface;
    final displayGroupTitle =
        widget.group.groupKey == TodoGroupingService.completedGroupKey
            ? context.tr('group.completed')
            : widget.group.groupKey == TodoGroupingService.uncategorizedGroupKey
                ? context.tr('group.uncategorized')
                : widget.group.title;

    final groupSubTextColor = widget.group.isCompletedAggregate
        ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.85)
        : theme.colorScheme.onSurfaceVariant;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: theme.brightness == Brightness.dark ? 0.7 : 0.92,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned.fill(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 5, color: accentColor),
                  const SizedBox(width: 0),
                ],
              ),
            ),
            Column(
              children: [
                InkWell(
                  onTap: _toggleExpanded,
                  borderRadius: headerBorderRadius,
                  customBorder: RoundedRectangleBorder(
                    borderRadius: headerBorderRadius,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onLongPress: widget.group.categoryId == null ||
                                    widget.group.isCompletedAggregate
                                ? null
                                : _showCategoryActions,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayGroupTitle,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: groupTextColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _noteCountLabel(widget.group.items.length),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: groupSubTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (widget.isManualSortEnabled)
                          ReorderableDragStartListener(
                            index: widget.groupIndex,
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6.0),
                              child: SizedBox(
                                width: 64,
                                height: 56,
                                child: Center(
                                  child: Icon(
                                    Icons.drag_indicator,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        IconButton(
                          onPressed: _toggleExpanded,
                          icon: AnimatedRotation(
                            turns: _isExpanded ? 0.5 : 0,
                            duration: const Duration(milliseconds: 180),
                            child: Icon(
                              Icons.expand_more,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  child: _isExpanded
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                          child: Column(
                            children: [
                              const SizedBox(height: 2),
                              if (widget.group.items.isNotEmpty)
                                _TodoGroupBody(
                                  items: widget.group.items,
                                  groupKey: widget.group.groupKey,
                                  categoryId: widget.group.categoryId,
                                  isCompletedAggregate:
                                      widget.group.isCompletedAggregate,
                                  isManualSortEnabled:
                                      widget.isManualSortEnabled,
                                  onMoveItemToGroup: widget.onMoveItemToGroup,
                                  onReorderWithinGroup:
                                      widget.onReorderWithinGroup,
                                )
                              else
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 18),
                                  child: Text(
                                    context.tr('home.empty.title'),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TodoGroupBody extends StatefulWidget {
  final List<TodoItem> items;
  final String groupKey;
  final String? categoryId;
  final bool isCompletedAggregate;
  final bool isManualSortEnabled;
  final Future<void> Function(
    String todoId,
    String? targetCategoryId,
    int targetIndex, {
    String? sourceGroupKey,
    int? sourceIndex,
  }) onMoveItemToGroup;
  final Future<void> Function(int oldIndex, int newIndex) onReorderWithinGroup;

  const _TodoGroupBody({
    required this.items,
    required this.groupKey,
    required this.categoryId,
    required this.isCompletedAggregate,
    required this.isManualSortEnabled,
    required this.onMoveItemToGroup,
    required this.onReorderWithinGroup,
  });

  @override
  State<_TodoGroupBody> createState() => _TodoGroupBodyState();
}

class _TodoGroupBodyState extends State<_TodoGroupBody> {
  @override
  Widget build(BuildContext context) {
    if (widget.isCompletedAggregate) {
      final completedChildren = <Widget>[];

      for (var index = 0; index < widget.items.length; index++) {
        completedChildren.add(
          TodoItemCard(
            key: ValueKey(widget.items[index].id),
            todoId: widget.items[index].id,
            showCategoryChip: false,
            compact: true,
            subdued: true,
          ),
        );

        if (index < widget.items.length - 1) {
          completedChildren.add(const SizedBox(height: 4));
        }
      }

      return Column(children: completedChildren);
    }

    if (!widget.isManualSortEnabled) {
      final staticChildren = <Widget>[];

      for (var index = 0; index < widget.items.length; index++) {
        staticChildren.add(
          Padding(
            key: ValueKey(widget.items[index].id),
            padding: EdgeInsets.only(
              bottom: index == widget.items.length - 1 ? 0 : 4,
            ),
            child: TodoItemCard(
              todoId: widget.items[index].id,
              showCategoryChip: false,
              compact: true,
              subdued: false,
            ),
          ),
        );
      }

      return Column(children: staticChildren);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.transparent,
      ),
      child: ReorderableListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        buildDefaultDragHandles: false,
        proxyDecorator: (child, index, animation) {
          return AnimatedBuilder(
            animation: animation,
            builder: (context, _) {
              final t = Curves.easeOut.transform(animation.value);
              return Transform.scale(
                scale: 1.0 + (0.02 * t),
                child: Material(
                  elevation: 8 + (4 * t),
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: child,
                ),
              );
            },
          );
        },
        itemCount: widget.items.length,
        onReorder: (oldIndex, newIndex) async {
          debugPrint(
              'intra-group onReorder called: $oldIndex -> $newIndex for group ${widget.groupKey}');
          // Adjust newIndex as ReorderableListView's newIndex refers to
          // the index after removal; when moving downwards the target
          // index is one greater than desired.
          if (oldIndex < newIndex) {
            newIndex -= 1;
          }
          await widget.onReorderWithinGroup(oldIndex, newIndex);
        },
        itemBuilder: (context, index) {
          final todo = widget.items[index];
          final isLastItem = index == widget.items.length - 1;

          return Padding(
            key: ValueKey(todo.id),
            padding: EdgeInsets.only(bottom: isLastItem ? 0 : 4),
            child: ReorderableDelayedDragStartListener(
              index: index,
              child: TodoItemCard(
                todoId: todo.id,
                showCategoryChip: false,
                compact: true,
                subdued: false,
              ),
            ),
          );
        },
      ),
    );
  }
}
