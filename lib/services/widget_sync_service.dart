import 'dart:convert';

import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/todo_item.dart';
import '../models/todo_priority.dart';

class WidgetSyncService {
  static const MethodChannel _channel = MethodChannel('com.audionotes/widgets');
  static const String _summaryPayloadKey = 'widget.todo.summary.payload';
  static const String _summaryUpdatedAtKey = 'widget.todo.summary.updated_at';

  Future<void> syncTodoSummary(List<TodoItem> todos) async {
    final visibleTodos = todos.where((todo) => todo.deletedAt == null).toList();
    final payload = _buildSummaryPayload(visibleTodos);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_summaryPayloadKey, jsonEncode(payload));
      await prefs.setString(
        _summaryUpdatedAtKey,
        DateTime.now().toIso8601String(),
      );

      foundation.debugPrint(
          'Widget sync: Saving payload with ${payload['sections'].length} sections');

      await _channel.invokeMethod<void>('refreshTodoWidgets');
      foundation.debugPrint('Widget sync: Triggered refresh for todo widgets');
    } catch (e) {
      foundation.debugPrint('Failed to sync widget summary: $e');
    }
  }

  Map<String, dynamic> _buildSummaryPayload(List<TodoItem> todos) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thisWeekEnd = today.add(const Duration(days: 7));
    final urgentItems =
        todos.where((todo) => todo.priority == TodoPriority.urgent).toList();
    final highPriorityItems =
        todos.where((todo) => todo.priority == TodoPriority.high).toList();

    final completedCount =
        todos.where((todo) => todo.status == TodoStatus.completed).length;
    final pendingTodos =
        todos.where((todo) => todo.status == TodoStatus.pending).toList();

    final thisWeekItems = pendingTodos
        .where((todo) {
          final dueAt = todo.dueAt;
          if (dueAt == null) {
            return false;
          }

          final dueDate = DateTime(dueAt.year, dueAt.month, dueAt.day);
          return dueDate.isBefore(thisWeekEnd) && !dueDate.isBefore(today);
        })
        .map(_mapTodoText)
        .toList();
    final highPriorityPendingItems = highPriorityItems
        .where((todo) => todo.status == TodoStatus.pending)
        .map(_mapTodoText)
        .toList();
    final urgentPendingItems = urgentItems
        .where((todo) => todo.status == TodoStatus.pending)
        .map(_mapTodoText)
        .toList();

    return <String, dynamic>{
      'title': '待办',
      'subtitle': _buildSubtitle(pendingTodos.length, completedCount),
      'totalCount': todos.length,
      'pendingCount': pendingTodos.length,
      'completedCount': completedCount,
      'updatedAt': DateTime.now().toIso8601String(),
      'sections': <Map<String, dynamic>>[
        _buildSection('紧急', urgentPendingItems),
        _buildSection('高优先级', highPriorityPendingItems),
        _buildSection('本周', thisWeekItems),
      ],
    };
  }

  Map<String, dynamic> _buildSection(String title, List<String> items) {
    final trimmedItems = items.take(3).toList();
    return <String, dynamic>{
      'title': title,
      'count': items.length,
      'items': trimmedItems,
    };
  }

  String _buildSubtitle(int pendingCount, int completedCount) {
    return '$pendingCount 待处理 · $completedCount 已完成';
  }

  String _mapTodoText(TodoItem todo) {
    final text = todo.text.trim();
    if (text.isNotEmpty) {
      return text;
    }

    final transcript = todo.rawTranscript?.trim();
    if (transcript != null && transcript.isNotEmpty) {
      return transcript;
    }

    return '未命名待办';
  }

  // bool _isSameDay(DateTime? left, DateTime rightDay) {
  // if (left == null) {
  //   return false;
  // }

  // return left.year == rightDay.year &&
  //     left.month == rightDay.month &&
  //     left.day == rightDay.day;
  // }
}
