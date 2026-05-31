import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_i18n.dart';
import '../models/tag.dart';
import '../models/todo_item.dart';
import '../models/todo_priority.dart';
import '../utils/priority_color.dart';
import '../providers/app_providers.dart';
import '../screens/category_picker_screen.dart';
import '../screens/tag_picker_screen.dart';
import '../utils/motion.dart';

enum _TodoCardLayoutMode {
  compact,
  standard,
  expanded,
}

/// Individual todo item card widget
class TodoItemCard extends ConsumerWidget {
  final String todoId;
  final bool showCategoryChip;
  final bool compact;
  final bool subdued;

  const TodoItemCard({
    super.key,
    required this.todoId,
    this.showCategoryChip = true,
    this.compact = false,
    this.subdued = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final notifier = ref.read(todoListProvider.notifier);
    final todo = ref.watch(todoByIdProvider(todoId));
    if (todo == null) {
      return const SizedBox.shrink();
    }

    final isSelected = notifier.isSelected(todo.id);
    final isSelectionMode = notifier.isSelectionMode;
    final isCompleted = todo.status == TodoStatus.completed;
    final isRecognizing = todo.taskState == TodoTaskState.recognizing;
    final priorityLabel = _resolvePriorityLabel(context, todo);
    final outerPadding = compact
        ? const EdgeInsets.symmetric(vertical: 0, horizontal: 0)
        : const EdgeInsets.symmetric(vertical: 2, horizontal: 8);
    final cardPadding = compact
        ? const EdgeInsets.fromLTRB(10, 8, 10, 8)
        : const EdgeInsets.fromLTRB(12, 8, 12, 8);
    final card = Padding(
      padding: outerPadding,
      child: _buildCard(
        context,
        ref,
        theme,
        notifier,
        todo,
        isSelected,
        isSelectionMode,
        isCompleted,
        isRecognizing,
        priorityLabel,
        cardPadding,
      ),
    );

    final visualCard = subdued
        ? Opacity(
            opacity: 0.72,
            child: card,
          )
        : card;

    return visualCard;
  }

  Widget _buildCard(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    TodoListNotifier notifier,
    TodoItem todo,
    bool isSelected,
    bool isSelectionMode,
    bool isCompleted,
    bool isRecognizing,
    String? priorityLabel,
    EdgeInsets cardPadding,
  ) {
    // Use batch tags cache when available to avoid N database queries
    final cachedTags = ref.watch(todoTagsCacheNotifierProvider)[todo.id];
    final tagsAsync = ref.watch(tagsForTodoProvider(todo.id));
    final fallbackTags = tagsAsync.maybeWhen(
      data: (items) => items,
      orElse: () => const <Tag>[],
    );
    final tags = (cachedTags ?? fallbackTags);

    final displayText = todo.text.isNotEmpty
        ? todo.text
        : (todo.rawTranscript != null && todo.rawTranscript!.isNotEmpty
            ? todo.rawTranscript!
            : context.tr('todo.recognizingInline'));

    if (isRecognizing) {
      return Container(
        margin: EdgeInsets.zero,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: theme.colorScheme.surface.withValues(
            alpha: theme.brightness == Brightness.dark ? 0.5 : 0.8,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: isSelectionMode
              ? () => notifier.toggleSelection(todo.id)
              : () => _showOptionsBottomSheet(context, ref, notifier, todo),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.tr('todo.recognizingTitle'),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.tr('todo.recognizingSubtitle'),
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      color: isSelectionMode && isSelected
          ? theme.colorScheme.primary.withValues(alpha: 0.12)
          : (isCompleted || subdued
              ? theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: subdued
                      ? (theme.brightness == Brightness.dark ? 0.62 : 0.82)
                      : (theme.brightness == Brightness.dark ? 0.55 : 0.7),
                )
              : null),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isSelectionMode
            ? () => notifier.toggleSelection(todo.id)
            : () => _showOptionsBottomSheet(context, ref, notifier, todo),
        child: Padding(
          padding: cardPadding,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final layoutMode = _resolveLayoutMode(constraints.maxWidth);

              return _buildResponsiveContent(
                context,
                theme,
                notifier,
                todo,
                isSelectionMode,
                isCompleted,
                isRecognizing,
                priorityLabel,
                tags,
                displayText,
                layoutMode,
                ref,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildResponsiveContent(
    BuildContext context,
    ThemeData theme,
    TodoListNotifier notifier,
    TodoItem todo,
    bool isSelectionMode,
    bool isCompleted,
    bool isRecognizing,
    String? priorityLabel,
    List<Tag> tags,
    String displayText,
    _TodoCardLayoutMode layoutMode,
    WidgetRef ref,
  ) {
    switch (layoutMode) {
      case _TodoCardLayoutMode.compact:
        return _buildCompactContent(
          context,
          theme,
          notifier,
          todo,
          isSelectionMode,
          isCompleted,
          isRecognizing,
          priorityLabel,
          tags,
          displayText,
          ref,
        );
      case _TodoCardLayoutMode.standard:
        return _buildStandardContent(
          context,
          theme,
          notifier,
          todo,
          isSelectionMode,
          isCompleted,
          isRecognizing,
          priorityLabel,
          tags,
          displayText,
          ref,
        );
      case _TodoCardLayoutMode.expanded:
        return _buildExpandedContent(
          context,
          theme,
          notifier,
          todo,
          isSelectionMode,
          isCompleted,
          isRecognizing,
          priorityLabel,
          tags,
          displayText,
          ref,
        );
    }
  }

  Widget _buildCompactContent(
    BuildContext context,
    ThemeData theme,
    TodoListNotifier notifier,
    TodoItem todo,
    bool isSelectionMode,
    bool isCompleted,
    bool isRecognizing,
    String? priorityLabel,
    List<Tag> tags,
    String displayText,
    WidgetRef ref,
  ) {
    return AnimatedSize(
      duration: isCompleted ? MotionTokens.micro : MotionTokens.short,
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeaderRow(
            context,
            theme,
            notifier,
            todo,
            displayText,
            isCompleted,
            isRecognizing,
            2,
            loweredTitle: true,
          ),
          _buildAnimatedVisibility(
            visible: !isCompleted,
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: _buildMetaRow(
                context,
                customTags: tags,
                priority: todo.priority,
                priorityLabel: priorityLabel,
                remindAt: todo.remindAt,
                dueAt: todo.dueAt,
                maxItems: 2,
                compact: true,
                alignment: WrapAlignment.start,
                onPriorityTap: isSelectionMode
                    ? null
                    : () => _showPriorityPicker(context, notifier, todo),
                onReminderTap: isSelectionMode
                    ? null
                    : () => _pickReminderTime(context, notifier, todo),
                onDueTap: isSelectionMode
                    ? null
                    : () => _pickDueTime(context, notifier, todo),
                onTagsTap: isSelectionMode
                    ? null
                    : () => _openTagPicker(context, ref, notifier, todo),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStandardContent(
    BuildContext context,
    ThemeData theme,
    TodoListNotifier notifier,
    TodoItem todo,
    bool isSelectionMode,
    bool isCompleted,
    bool isRecognizing,
    String? priorityLabel,
    List<Tag> tags,
    String displayText,
    WidgetRef ref,
  ) {
    return AnimatedSize(
      duration:
          isCompleted ? const Duration(milliseconds: 10) : MotionTokens.short,
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeaderRow(
            context,
            theme,
            notifier,
            todo,
            displayText,
            isCompleted,
            isRecognizing,
            1,
            loweredTitle: true,
          ),
          _buildAnimatedVisibility(
            visible: !isCompleted,
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: _buildMetaRow(
                context,
                customTags: tags,
                priority: todo.priority,
                priorityLabel: priorityLabel,
                remindAt: todo.remindAt,
                dueAt: todo.dueAt,
                maxItems: 3,
                compact: false,
                alignment: WrapAlignment.start,
                onPriorityTap: isSelectionMode
                    ? null
                    : () => _showPriorityPicker(context, notifier, todo),
                onReminderTap: isSelectionMode
                    ? null
                    : () => _pickReminderTime(context, notifier, todo),
                onDueTap: isSelectionMode
                    ? null
                    : () => _pickDueTime(context, notifier, todo),
                onTagsTap: isSelectionMode
                    ? null
                    : () => _openTagPicker(context, ref, notifier, todo),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedContent(
    BuildContext context,
    ThemeData theme,
    TodoListNotifier notifier,
    TodoItem todo,
    bool isSelectionMode,
    bool isCompleted,
    bool isRecognizing,
    String? priorityLabel,
    List<Tag> tags,
    String displayText,
    WidgetRef ref,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: _buildTitleBlock(
              context,
              theme,
              todo,
              displayText,
              isCompleted,
              isRecognizing,
              1,
            ),
          ),
        ),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 240),
          child: _buildInlineMetaRow(
            context,
            customTags: tags,
            priority: todo.priority,
            priorityLabel: priorityLabel,
            remindAt: todo.remindAt,
            dueAt: todo.dueAt,
            maxItems: 4,
            compact: false,
            onPriorityTap: isSelectionMode
                ? null
                : () => _showPriorityPicker(context, notifier, todo),
            onReminderTap: isSelectionMode
                ? null
                : () => _pickReminderTime(context, notifier, todo),
            onDueTap: isSelectionMode
                ? null
                : () => _pickDueTime(context, notifier, todo),
            onTagsTap: isSelectionMode
                ? null
                : () => _openTagPicker(context, ref, notifier, todo),
          ),
        ),
        const SizedBox(width: 4),
        _buildStatusCheckbox(context, notifier, todo),
      ],
    );
  }

  Widget _buildHeaderRow(
      BuildContext context,
      ThemeData theme,
      TodoListNotifier notifier,
      TodoItem todo,
      String displayText,
      bool isCompleted,
      bool isRecognizing,
      int maxLines,
      {bool loweredTitle = false}) {
    final rowAlignment =
        maxLines == 1 ? CrossAxisAlignment.center : CrossAxisAlignment.start;

    return Row(
      crossAxisAlignment: rowAlignment,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 6),
            child: _buildTitleBlock(
              context,
              theme,
              todo,
              displayText,
              isCompleted,
              isRecognizing,
              maxLines,
              loweredTitle: loweredTitle,
            ),
          ),
        ),
        _buildStatusCheckbox(context, notifier, todo),
      ],
    );
  }

  Widget _buildTitleBlock(BuildContext context, ThemeData theme, TodoItem todo,
      String displayText, bool isCompleted, bool isRecognizing, int maxLines,
      {bool loweredTitle = false}) {
    final measurementStyle = TextStyle(
      fontSize: 19,
      height: 1.05,
      fontWeight: FontWeight.w600,
      color: theme.colorScheme.onSurface,
    );

    final titleStyle = isCompleted
        ? measurementStyle.copyWith(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.78),
          )
        : measurementStyle;

    final titleWidget = AnimatedDefaultTextStyle(
      duration: MotionTokens.short,
      curve: Curves.easeInOutCubic,
      style: titleStyle,
      child: Text(
        displayText,
        maxLines: maxLines,
        overflow: TextOverflow.ellipsis,
      ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final displayedLineCount = _displayedLineCount(
          displayText,
          measurementStyle,
          constraints.maxWidth,
          maxLines,
          context,
        );
        final fitsOnSingleLine = _fitsOnSingleLine(
          displayText,
          measurementStyle,
          constraints.maxWidth,
          context,
        );

        final shouldPadForMultiLine = loweredTitle && displayedLineCount > 1;

        final shouldBottomAlign = loweredTitle &&
            fitsOnSingleLine &&
            !isRecognizing &&
            !(todo.taskState == TodoTaskState.failed &&
                todo.errorMessage != null);

        if (shouldBottomAlign) {
          return SizedBox(
            height: 24,
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Transform.translate(
                offset: const Offset(0, 2),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: titleWidget,
                ),
              ),
            ),
          );
        }

        if (shouldPadForMultiLine) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                titleWidget,
                if (isRecognizing)
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: LinearProgressIndicator(),
                  ),
                if (todo.taskState == TodoTaskState.failed &&
                    todo.errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      context.tr('todo.failedWithError', params: {
                        'error': _displayErrorMessage(
                          context,
                          todo.errorMessage,
                        )
                      }),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.red,
                      ),
                    ),
                  ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            titleWidget,
            if (isRecognizing)
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: LinearProgressIndicator(),
              ),
            if (todo.taskState == TodoTaskState.failed &&
                todo.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  context.tr('todo.failedWithError', params: {
                    'error': _displayErrorMessage(
                      context,
                      todo.errorMessage,
                    )
                  }),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.red,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  bool _fitsOnSingleLine(
    String text,
    TextStyle style,
    double maxWidth,
    BuildContext context,
  ) {
    if (maxWidth <= 0) {
      return false;
    }

    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: maxWidth);

    return !textPainter.didExceedMaxLines;
  }

  int _displayedLineCount(
    String text,
    TextStyle style,
    double maxWidth,
    int maxLines,
    BuildContext context,
  ) {
    if (maxWidth <= 0) {
      return 1;
    }

    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: maxLines,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: maxWidth);

    return textPainter.computeLineMetrics().length;
  }

  Widget _buildStatusCheckbox(
    BuildContext context,
    TodoListNotifier notifier,
    TodoItem todo,
  ) {
    return Checkbox(
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      value: todo.status == TodoStatus.completed,
      onChanged: notifier.isStatusUpdating(todo.id)
          ? null
          : (value) => _setStatus(
                notifier,
                value == true ? TodoStatus.completed : TodoStatus.pending,
                todo,
              ),
    );
  }

  String? _resolvePriorityLabel(BuildContext context, TodoItem todo) {
    switch (todo.priority) {
      case TodoPriority.low:
        return context.tr('settings.todo.priority.low');
      case TodoPriority.normal:
        return context.tr('settings.todo.priority.normal');
      case TodoPriority.high:
        return context.tr('settings.todo.priority.high');
      case TodoPriority.urgent:
        return context.tr('settings.todo.priority.urgent');
    }
  }

  Widget _buildMetaRow(
    BuildContext context, {
    required List<Tag> customTags,
    required TodoPriority priority,
    required String? priorityLabel,
    required DateTime? remindAt,
    required DateTime? dueAt,
    required int maxItems,
    required bool compact,
    required WrapAlignment alignment,
    VoidCallback? onPriorityTap,
    VoidCallback? onReminderTap,
    VoidCallback? onDueTap,
    VoidCallback? onTagsTap,
  }) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;
        final foldThreshold = availableWidth * 0.8;
        final chips = <_MetaChipData>[];

        void addChip({
          required IconData icon,
          required String label,
          required Color color,
          VoidCallback? onTap,
        }) {
          chips.add(
            _MetaChipData(
              icon: icon,
              label: label,
              color: color,
              onTap: onTap,
              estimatedWidth: _estimateTagPillWidth(label, compact: compact),
            ),
          );
        }

        if (priorityLabel != null && priorityLabel.trim().isNotEmpty) {
          addChip(
            icon: Icons.flag_outlined,
            label: priorityLabel,
            color: resolvePriorityColor(context, priority),
            onTap: onPriorityTap,
          );
        }

        if (remindAt != null) {
          addChip(
            icon: Icons.notifications_active_outlined,
            label: _formatRelativeDate(remindAt, compact: compact),
            color: theme.colorScheme.secondary,
            onTap: onReminderTap,
          );
        }

        if (dueAt != null) {
          addChip(
            icon: Icons.event_outlined,
            label: _formatRelativeDate(dueAt, compact: compact),
            color: theme.colorScheme.tertiary,
            onTap: onDueTap,
          );
        }

        for (final tag in customTags) {
          addChip(
            icon: Icons.label,
            label: tag.name,
            color: Color(tag.color ?? theme.colorScheme.primary.toARGB32()),
            onTap: onTagsTap,
          );
        }

        if (chips.isEmpty) {
          return SizedBox(
            height: compact ? 16 : 18,
            width: double.infinity,
          );
        }

        final shouldFoldByWidth = chips.fold<double>(0, (sum, chip) {
              return sum + chip.estimatedWidth;
            }) >
            foldThreshold;

        final effectiveMaxItems =
            shouldFoldByWidth ? (maxItems < 1 ? 1 : maxItems) : chips.length;
        final displayChipData = chips.length <= effectiveMaxItems
            ? chips
            : <_MetaChipData>[
                ...chips.take(effectiveMaxItems - 1),
                _MetaChipData.overflow(
                  remainingCount: chips.length - (effectiveMaxItems - 1),
                  color: theme.colorScheme.outline,
                ),
              ];
        final displayChips = displayChipData.map((chip) {
          if (chip.isOverflow) {
            return _buildOverflowChip(
              context,
              chip.remainingCount ?? 0,
              compact: compact,
            );
          }

          return _buildTagPill(
            context,
            icon: chip.icon!,
            label: chip.label!,
            color: chip.color!,
            compact: compact,
            onTap: chip.onTap,
          );
        }).toList(growable: false);

        return Wrap(
          spacing: compact ? 3 : 4,
          runSpacing: compact ? 1 : 2,
          alignment: alignment,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: displayChips,
        );
      },
    );
  }

  Widget _buildAnimatedVisibility({
    required bool visible,
    required Widget child,
  }) {
    return AnimatedSwitcher(
      duration: MotionTokens.short,
      reverseDuration: MotionTokens.short,
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.topLeft,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      transitionBuilder: (child, animation) {
        final fade = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        );
        final scale = Tween<double>(
          begin: 0.985,
          end: 1.0,
        ).animate(
          CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
          ),
        );

        return ClipRect(
          child: FadeTransition(
            opacity: fade,
            child: ScaleTransition(
              scale: scale,
              alignment: Alignment.topLeft,
              child: child,
            ),
          ),
        );
      },
      child: visible
          ? KeyedSubtree(
              key: const ValueKey('meta-visible'),
              child: child,
            )
          : const SizedBox.shrink(key: ValueKey('meta-hidden')),
    );
  }

  Widget _buildInlineMetaRow(
    BuildContext context, {
    required List<Tag> customTags,
    required TodoPriority priority,
    required String? priorityLabel,
    required DateTime? remindAt,
    required DateTime? dueAt,
    required int maxItems,
    required bool compact,
    VoidCallback? onPriorityTap,
    VoidCallback? onReminderTap,
    VoidCallback? onDueTap,
    VoidCallback? onTagsTap,
  }) {
    final theme = Theme.of(context);
    final chips = <Widget>[];

    if (priorityLabel != null && priorityLabel.trim().isNotEmpty) {
      chips.add(
        _buildTagPill(
          context,
          icon: Icons.flag_outlined,
          label: priorityLabel,
          color: resolvePriorityColor(context, priority),
          compact: compact,
          onTap: onPriorityTap,
        ),
      );
    }

    if (remindAt != null) {
      chips.add(
        _buildTagPill(
          context,
          icon: Icons.notifications_active_outlined,
          label: _formatRelativeDate(remindAt, compact: compact),
          color: theme.colorScheme.secondary,
          compact: compact,
          onTap: onReminderTap,
        ),
      );
    }

    if (dueAt != null) {
      chips.add(
        _buildTagPill(
          context,
          icon: Icons.event_outlined,
          label: _formatRelativeDate(dueAt, compact: compact),
          color: theme.colorScheme.tertiary,
          compact: compact,
          onTap: onDueTap,
        ),
      );
    }

    for (final tag in customTags) {
      chips.add(
        _buildTagPill(
          context,
          icon: Icons.label,
          label: tag.name,
          color: Color(tag.color ?? theme.colorScheme.primary.toARGB32()),
          compact: compact,
          onTap: onTagsTap,
        ),
      );
    }

    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }

    final effectiveMaxItems = maxItems < 1 ? 1 : maxItems;
    final displayChips = chips.length <= effectiveMaxItems
        ? chips
        : <Widget>[
            ...chips.take(effectiveMaxItems - 1),
            _buildOverflowChip(
              context,
              chips.length - (effectiveMaxItems - 1),
              compact: compact,
            ),
          ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < displayChips.length; index++) ...[
          if (index > 0) SizedBox(width: compact ? 4 : 5),
          displayChips[index],
        ],
      ],
    );
  }

  Widget _buildTagPill(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required bool compact,
    VoidCallback? onTap,
  }) {
    final pill = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: compact ? 104 : 140),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 5 : 7,
          vertical: compact ? 2 : 3,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.38)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: compact ? 10 : 11, color: color),
            SizedBox(width: compact ? 2 : 2),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: compact ? 10 : 11,
                    ),
              ),
            ),
          ],
        ),
      ),
    );

    if (onTap == null) {
      return pill;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: pill,
    );
  }

  double _estimateTagPillWidth(String label, {required bool compact}) {
    final textStyle = TextStyle(
      fontSize: compact ? 10 : 11,
      fontWeight: FontWeight.w600,
    );
    final textPainter = TextPainter(
      text: TextSpan(text: label, style: textStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    final horizontalPadding = compact ? 10.0 : 14.0;
    final iconWidth = compact ? 10.0 : 11.0;
    final gapWidth = compact ? 2.0 : 2.0;
    return textPainter.width + horizontalPadding + iconWidth + gapWidth;
  }

  Widget _buildOverflowChip(
    BuildContext context,
    int remainingCount, {
    required bool compact,
  }) {
    final theme = Theme.of(context);
    return _buildTagPill(
      context,
      icon: Icons.more_horiz,
      label: '+$remainingCount',
      color: theme.colorScheme.outline,
      compact: compact,
    );
  }

  String _formatTime(DateTime dateTime) {
    return '${_twoDigits(dateTime.hour)}:${_twoDigits(dateTime.minute)}';
  }

  String _formatRelativeDate(DateTime dateTime, {bool compact = false}) {
    final now = DateTime.now();
    final sameDay = now.year == dateTime.year &&
        now.month == dateTime.month &&
        now.day == dateTime.day;
    if (sameDay) {
      return _formatTime(dateTime);
    }
    if (compact) {
      return '${_twoDigits(dateTime.month)}/${_twoDigits(dateTime.day)}';
    }
    return '${_twoDigits(dateTime.month)}/${_twoDigits(dateTime.day)} ${_formatTime(dateTime)}';
  }

  _TodoCardLayoutMode _resolveLayoutMode(double maxWidth) {
    if (maxWidth < 380) {
      return _TodoCardLayoutMode.compact;
    }

    if (maxWidth < 520) {
      return _TodoCardLayoutMode.standard;
    }

    return _TodoCardLayoutMode.expanded;
  }

  String _twoDigits(int n) {
    return n.toString().padLeft(2, '0');
  }

  void _setStatus(TodoListNotifier notifier, TodoStatus status, TodoItem todo) {
    notifier.setCompletionStatus(todo.id, status);
  }

  void _showOptionsBottomSheet(
    BuildContext context,
    WidgetRef ref,
    TodoListNotifier notifier,
    TodoItem todo,
  ) {
    final isCompleted = todo.status == TodoStatus.completed;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => motionEntrance(
        sheetContext,
        SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: Text(context.tr('todo.editAction')),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showEditDialog(context, notifier, todo);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.category_outlined),
                  title: Text(context.tr('todo.setCategory')),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openCategoryPicker(context, ref, notifier, todo);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: Text(context.tr('todo.setReminderTime')),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickReminderTime(context, notifier, todo);
                  },
                ),
                if (todo.remindAt != null)
                  ListTile(
                    leading: const Icon(Icons.notifications_off_outlined),
                    title: Text(context.tr('todo.clearReminderTime')),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _clearReminderTime(context, notifier, todo);
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.event_outlined),
                  title: Text(context.tr('todo.setDueTime')),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickDueTime(context, notifier, todo);
                  },
                ),
                if (todo.dueAt != null)
                  ListTile(
                    leading: const Icon(Icons.event_busy_outlined),
                    title: Text(context.tr('todo.clearDueTime')),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _clearDueTime(context, notifier, todo);
                    },
                  ),
                ListTile(
                  leading: const Icon(Icons.flag),
                  title: Text(context.tr('todo.setPriority')),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showPriorityPicker(context, notifier, todo);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.label_outline),
                  title: Text(context.tr('todo.editTags')),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _openTagPicker(context, ref, notifier, todo);
                  },
                ),
                if (!isCompleted)
                  ListTile(
                    leading: const Icon(Icons.mic),
                    title: Text(context.tr('todo.reRecordAction')),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _reRecord(context, ref, todo);
                    },
                  ),
                // Playback option removed: audio files are deleted after recognition
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: Text(context.tr('common.delete'),
                      style: const TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _confirmDelete(context, notifier, todo);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showPriorityPicker(
    BuildContext context,
    TodoListNotifier notifier,
    TodoItem todo,
  ) async {
    final picked = await showModalBottomSheet<TodoPriority>(
      context: context,
      builder: (ctx) {
        return motionEntrance(
          ctx,
          SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: TodoPriority.values.map((p) {
                return ListTile(
                  title: Text(_priorityToLabel(context, p)),
                  onTap: () => Navigator.pop(ctx, p),
                );
              }).toList(),
            ),
          ),
        );
      },
    );

    if (picked != null && picked != todo.priority) {
      await notifier.updatePriority(todo.id, picked);
    }
  }

  String _priorityToLabel(BuildContext context, TodoPriority p) {
    switch (p) {
      case TodoPriority.low:
        return context.tr('settings.todo.priority.low');
      case TodoPriority.normal:
        return context.tr('settings.todo.priority.normal');
      case TodoPriority.high:
        return context.tr('settings.todo.priority.high');
      case TodoPriority.urgent:
        return context.tr('settings.todo.priority.urgent');
    }
  }

  Future<void> _openCategoryPicker(
    BuildContext context,
    WidgetRef ref,
    TodoListNotifier notifier,
    TodoItem todo,
  ) async {
    final navigator = Navigator.of(context);
    final selected = await navigator.push<String>(
      MaterialPageRoute(
        builder: (_) => CategoryPickerScreen(
          selectedCategoryId: todo.categoryId,
        ),
      ),
    );

    if (selected == null) return;
    await notifier.updateCategory(todo.id, selected);
  }

  Future<void> _pickReminderTime(
    BuildContext context,
    TodoListNotifier notifier,
    TodoItem todo,
  ) async {
    final picked = await _pickDateTime(
      context,
      initialDateTime:
          todo.remindAt ?? DateTime.now().add(const Duration(hours: 1)),
      title: context.tr('todo.pickReminderTimeTitle'),
    );

    if (picked == null || !context.mounted) return;
    await notifier.updateReminderTime(todo.id, picked);
  }

  Future<void> _pickDueTime(
    BuildContext context,
    TodoListNotifier notifier,
    TodoItem todo,
  ) async {
    final picked = await _pickDateTime(
      context,
      initialDateTime:
          todo.dueAt ?? DateTime.now().add(const Duration(days: 1)),
      title: context.tr('todo.pickDueTimeTitle'),
    );

    if (picked == null || !context.mounted) return;
    await notifier.updateDueTime(todo.id, picked);
  }

  Future<DateTime?> _pickDateTime(
    BuildContext context, {
    required DateTime initialDateTime,
    required String title,
  }) async {
    final initialDate = DateTime(
      initialDateTime.year,
      initialDateTime.month,
      initialDateTime.day,
    );

    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: title,
    );

    if (date == null || !context.mounted) {
      return null;
    }

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDateTime),
    );

    if (time == null) {
      return null;
    }

    return DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
  }

  Future<void> _clearReminderTime(
    BuildContext context,
    TodoListNotifier notifier,
    TodoItem todo,
  ) async {
    await notifier.updateReminderTime(todo.id, null);
    if (context.mounted) {
      _showToast(context, context.tr('todo.clearedReminderTimeToast'));
    }
  }

  Future<void> _clearDueTime(
    BuildContext context,
    TodoListNotifier notifier,
    TodoItem todo,
  ) async {
    await notifier.updateDueTime(todo.id, null);
    if (context.mounted) {
      _showToast(context, context.tr('todo.clearedDueTimeToast'));
    }
  }

  Future<void> _openTagPicker(
    BuildContext context,
    WidgetRef ref,
    TodoListNotifier notifier,
    TodoItem todo,
  ) async {
    final navigator = Navigator.of(context);
    final current =
        await ref.read(tagRepositoryProvider).getTagsForTodo(todo.id);
    final selectedIds = current.map((t) => t.id).toList();
    final picked = await navigator.push<List<String>>(
      MaterialPageRoute(
        builder: (_) => TagPickerScreen(initialSelected: selectedIds),
      ),
    );

    if (picked == null) return;
    await notifier.setTags(todo.id, picked);
  }

  void _showEditDialog(
      BuildContext context, TodoListNotifier notifier, TodoItem todo) {
    final controller = TextEditingController(
      text: todo.text.isNotEmpty ? todo.text : (todo.rawTranscript ?? ''),
    );

    showDialog(
      context: context,
      builder: (dialogContext) => motionEntrance(
        dialogContext,
        AlertDialog(
          title: Text(context.tr('todo.editDialogTitle')),
          content: TextField(
            controller: controller,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: context.tr('todo.editDialogHint'),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.tr('common.cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                final navigator = Navigator.of(dialogContext);
                await notifier.updateText(todo.id, controller.text.trim());
                navigator.pop();
              },
              child: Text(context.tr('common.save')),
            ),
          ],
        ),
      ),
    );
  }

  void _reRecord(BuildContext context, WidgetRef ref, TodoItem todo) {
    final recordingNotifier = ref.read(recordingStateProvider.notifier);

    recordingNotifier.startReRecord(todo).catchError((error) {
      if (context.mounted) {
        _showToast(
          context,
          context.tr('todo.reRecordFailed', params: {'error': '$error'}),
        );
      }
    });
  }

  // Playback removed: audio files are deleted after recognition and playback UI is not available.

  void _showToast(BuildContext context, String message) {
    final overlay = Overlay.of(context);

    final entry = OverlayEntry(
      builder: (context) => Positioned(
        left: 16,
        right: 16,
        bottom: 24,
        child: SafeArea(
          child: ExcludeSemantics(
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 2), entry.remove);
  }

  void _confirmDelete(
      BuildContext context, TodoListNotifier notifier, TodoItem todo) {
    showDialog(
      context: context,
      builder: (dialogContext) => motionEntrance(
        dialogContext,
        AlertDialog(
          title: Text(context.tr('todo.deleteDialogTitle')),
          content: Text(context.tr('todo.deleteDialogContent')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.tr('common.cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () async {
                await notifier.deleteTodo(todo.id);
                if (context.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              child: Text(context.tr('common.delete')),
            ),
          ],
        ),
      ),
    );
  }

  String _displayErrorMessage(BuildContext context, String? raw) {
    if (raw == null || raw.isEmpty) {
      return '';
    }

    final value = raw.startsWith('Exception: ') ? raw.substring(11) : raw;
    switch (value) {
      case 'error.recordingFileGenerationFailed':
        return context.tr('errors.recordingFileGenerationFailed');
      case 'error.speechRecognitionFailed':
        return context.tr('errors.speechRecognitionFailed');
      default:
        return raw;
    }
  }
}

class _MetaChipData {
  final IconData? icon;
  final String? label;
  final Color? color;
  final VoidCallback? onTap;
  final double estimatedWidth;
  final bool isOverflow;
  final int? remainingCount;

  const _MetaChipData({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    required this.estimatedWidth,
  })  : isOverflow = false,
        remainingCount = null;

  const _MetaChipData.overflow({
    required this.remainingCount,
    required this.color,
  })  : icon = null,
        label = null,
        onTap = null,
        estimatedWidth = 40,
        isOverflow = true;
}
