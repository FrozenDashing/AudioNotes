import 'todo_item.dart';

/// Group of todos shown under a category header.
class TodoGroup {
  final String groupKey;
  final String title;
  final String? categoryId;
  final int? color;
  final List<TodoItem> items;
  final bool isExpanded;
  final int groupOrderIndex;
  final bool isCompletedAggregate;

  const TodoGroup({
    required this.groupKey,
    required this.title,
    required this.items,
    required this.isExpanded,
    required this.groupOrderIndex,
    this.isCompletedAggregate = false,
    this.categoryId,
    this.color,
  });

  TodoGroup copyWith({
    String? groupKey,
    String? title,
    String? categoryId,
    int? color,
    List<TodoItem>? items,
    bool? isExpanded,
    int? groupOrderIndex,
    bool? isCompletedAggregate,
  }) {
    return TodoGroup(
      groupKey: groupKey ?? this.groupKey,
      title: title ?? this.title,
      categoryId: categoryId ?? this.categoryId,
      color: color ?? this.color,
      items: items ?? this.items,
      isExpanded: isExpanded ?? this.isExpanded,
      groupOrderIndex: groupOrderIndex ?? this.groupOrderIndex,
      isCompletedAggregate: isCompletedAggregate ?? this.isCompletedAggregate,
    );
  }
}
