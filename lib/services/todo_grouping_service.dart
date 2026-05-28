import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show compute;

import '../models/category.dart';
import '../models/todo_group.dart';
import '../models/todo_item.dart';
import '../models/todo_sort.dart';

/// Builds category-based todo groups and persists group order.
class TodoGroupingService {
  static const String _groupOrderKey = 'todo_group_order_map';
  static const String _expandedMapKey = 'todo_group_expanded_map';
  static const String uncategorizedGroupKey = 'uncategorized';
  static const String completedGroupKey = 'completed_aggregate';

  Future<Map<String, int>> loadGroupOrderMap() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_groupOrderKey);
    if (encoded == null || encoded.isEmpty) {
      return {};
    }

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) {
        return {};
      }

      return decoded.map(
        (key, value) => MapEntry(key.toString(), value is int ? value : 0),
      );
    } catch (_) {
      return {};
    }
  }

  Future<void> saveGroupOrderMap(Map<String, int> orderMap) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_groupOrderKey, jsonEncode(orderMap));
  }

  Future<Map<String, bool>> loadExpandedMap() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_expandedMapKey);
    if (encoded == null || encoded.isEmpty) return {};

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) return {};
      return decoded
          .map((key, value) => MapEntry(key.toString(), value == true));
    } catch (_) {
      return {};
    }
  }

  Future<void> saveExpandedMap(Map<String, bool> expandedMap) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_expandedMapKey, jsonEncode(expandedMap));
  }

  List<TodoGroup> buildGroups({
    required List<TodoItem> todos,
    required List<Category> categories,
    required TodoSortField sortField,
    required SortDirection direction,
    bool aggregateCompletedTodos = false,
    Map<String, int> groupOrderMap = const {},
  }) {
    final categoryById = <String, Category>{
      for (final category in categories) category.id: category,
    };

    final buckets = <String, List<TodoItem>>{};
    for (final todo in todos) {
      if (aggregateCompletedTodos && todo.status == TodoStatus.completed) {
        buckets.putIfAbsent(completedGroupKey, () => <TodoItem>[]).add(todo);
        continue;
      }

      final groupKey = todo.categoryId ?? uncategorizedGroupKey;
      buckets.putIfAbsent(groupKey, () => <TodoItem>[]).add(todo);
    }

    final groups = buckets.entries.map((entry) {
      final groupKey = entry.key;
      final isCompletedAggregate = groupKey == completedGroupKey;
      final category = categoryById[groupKey];
      final isUncategorized = groupKey == uncategorizedGroupKey;
      final sortedItems =
          _sortTodosWithinGroup(entry.value, sortField, direction);
      final fallbackOrderIndex = isCompletedAggregate
          ? 1 << 30
          : isUncategorized
              ? (1 << 30) - 1
              : categories
                  .indexWhere((categoryItem) => categoryItem.id == groupKey);

      return TodoGroup(
        groupKey: groupKey,
        title: isCompletedAggregate
            ? '已完成'
            : (isUncategorized ? '未分类' : (category?.name ?? '未分类')),
        categoryId:
            (isUncategorized || isCompletedAggregate) ? null : category?.id,
        color: isCompletedAggregate
            ? null
            : (isUncategorized ? null : category?.color),
        items: sortedItems,
        isExpanded: true,
        isCompletedAggregate: isCompletedAggregate,
        groupOrderIndex: groupOrderMap[groupKey] ??
            (fallbackOrderIndex < 0 ? 1 << 29 : fallbackOrderIndex),
      );
    }).toList();

    groups.sort((left, right) {
      final orderCompare =
          left.groupOrderIndex.compareTo(right.groupOrderIndex);
      if (orderCompare != 0) {
        return orderCompare;
      }
      return left.title.compareTo(right.title);
    });

    return groups;
  }

  List<TodoItem> _sortTodosWithinGroup(
    List<TodoItem> items,
    TodoSortField sortField,
    SortDirection direction,
  ) {
    final sorted = List<TodoItem>.from(items);

    int compareNullable<T extends Comparable<Object>>(T? left, T? right) {
      if (left == null && right == null) return 0;
      if (left == null) return 1;
      if (right == null) return -1;
      return left.compareTo(right);
    }

    int compareDateTime(DateTime? left, DateTime? right) {
      if (left == null && right == null) return 0;
      if (left == null) return 1;
      if (right == null) return -1;
      return direction == SortDirection.asc
          ? left.compareTo(right)
          : right.compareTo(left);
    }

    sorted.sort((left, right) {
      switch (sortField) {
        case TodoSortField.manual:
          final orderCompare =
              compareNullable(left.orderIndex, right.orderIndex);
          if (orderCompare != 0) return orderCompare;
          return right.createdAt.compareTo(left.createdAt);
        case TodoSortField.createdAt:
          return direction == SortDirection.asc
              ? left.createdAt.compareTo(right.createdAt)
              : right.createdAt.compareTo(left.createdAt);
        case TodoSortField.dueAt:
          final dueCompare = compareDateTime(left.dueAt, right.dueAt);
          if (dueCompare != 0) return dueCompare;
          return right.createdAt.compareTo(left.createdAt);
        case TodoSortField.priority:
          final priorityCompare = direction == SortDirection.asc
              ? left.priority.value.compareTo(right.priority.value)
              : right.priority.value.compareTo(left.priority.value);
          if (priorityCompare != 0) return priorityCompare;
          return right.createdAt.compareTo(left.createdAt);
      }
    });

    return sorted;
  }

  /// Offload sorting to a background isolate using `compute`.
  Future<List<TodoItem>> sortTodosInBackground(List<TodoItem> items,
      TodoSortField sortField, SortDirection direction) async {
    final payload = {
      'items': items.map((t) => t.toJson()).toList(),
      'sortField': sortField.toString().split('.').last,
      'direction': direction == SortDirection.asc ? 'asc' : 'desc',
    };

    final result = await compute(_backgroundSortPayload, payload);
    return result
        .cast<Map<String, dynamic>>()
        .map((m) => TodoItem.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }
}

// Top-level function for compute to perform sorting in an isolate.
List<Map<String, dynamic>> _backgroundSortPayload(
    Map<String, dynamic> payload) {
  final itemsJson = (payload['items'] as List).cast<Map<String, dynamic>>();
  final sortFieldName = payload['sortField'] as String? ?? 'manual';
  final directionName = payload['direction'] as String? ?? 'asc';

  final items = itemsJson
      .map((m) => TodoItem.fromJson(Map<String, dynamic>.from(m)))
      .toList();

  final sortField = TodoSortField.values.firstWhere(
      (v) => v.toString().split('.').last == sortFieldName,
      orElse: () => TodoSortField.manual);
  final direction =
      directionName == 'asc' ? SortDirection.asc : SortDirection.desc;

  int compareNullable<T extends Comparable<Object>>(T? left, T? right) {
    if (left == null && right == null) return 0;
    if (left == null) return 1;
    if (right == null) return -1;
    return left.compareTo(right);
  }

  int compareDateTime(DateTime? left, DateTime? right) {
    if (left == null && right == null) return 0;
    if (left == null) return 1;
    if (right == null) return -1;
    return direction == SortDirection.asc
        ? left.compareTo(right)
        : right.compareTo(left);
  }

  items.sort((left, right) {
    switch (sortField) {
      case TodoSortField.manual:
        final orderCompare = compareNullable(left.orderIndex, right.orderIndex);
        if (orderCompare != 0) return orderCompare;
        return right.createdAt.compareTo(left.createdAt);
      case TodoSortField.createdAt:
        return direction == SortDirection.asc
            ? left.createdAt.compareTo(right.createdAt)
            : right.createdAt.compareTo(left.createdAt);
      case TodoSortField.dueAt:
        final dueCompare = compareDateTime(left.dueAt, right.dueAt);
        if (dueCompare != 0) return dueCompare;
        return right.createdAt.compareTo(left.createdAt);
      case TodoSortField.priority:
        final priorityCompare = direction == SortDirection.asc
            ? left.priority.value.compareTo(right.priority.value)
            : right.priority.value.compareTo(left.priority.value);
        if (priorityCompare != 0) return priorityCompare;
        return right.createdAt.compareTo(left.createdAt);
    }
  });

  return items.map((t) => t.toJson()).toList();
}
