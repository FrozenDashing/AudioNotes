import 'package:flutter/material.dart';
import '../models/todo_priority.dart';
import '../themes/todo_priority_palette.dart';

Color resolvePriorityColor(BuildContext context, TodoPriority priority) {
  final palette = Theme.of(context).extension<TodoPriorityPalette>();
  if (palette == null) {
    // Fallback mapping if extension not provided
    switch (priority) {
      case TodoPriority.urgent:
        return const Color(0xFFE5484D);
      case TodoPriority.high:
        return const Color(0xFFF97316);
      case TodoPriority.normal:
        return const Color(0xFF3B82F6);
      case TodoPriority.low:
        return const Color(0xFF22C55E);
    }
  }

  switch (priority) {
    case TodoPriority.urgent:
      return palette.urgent;
    case TodoPriority.high:
      return palette.high;
    case TodoPriority.normal:
      return palette.normal;
    case TodoPriority.low:
      return palette.low;
  }
}
