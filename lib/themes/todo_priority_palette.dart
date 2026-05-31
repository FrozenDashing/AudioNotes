import 'package:flutter/material.dart';

@immutable
class TodoPriorityPalette extends ThemeExtension<TodoPriorityPalette> {
  final Color urgent;
  final Color high;
  final Color normal;
  final Color low;

  const TodoPriorityPalette({
    required this.urgent,
    required this.high,
    required this.normal,
    required this.low,
  });

  @override
  TodoPriorityPalette copyWith(
          {Color? urgent, Color? high, Color? normal, Color? low}) =>
      TodoPriorityPalette(
        urgent: urgent ?? this.urgent,
        high: high ?? this.high,
        normal: normal ?? this.normal,
        low: low ?? this.low,
      );

  @override
  TodoPriorityPalette lerp(
      ThemeExtension<TodoPriorityPalette>? other, double t) {
    if (other is! TodoPriorityPalette) return this;
    return TodoPriorityPalette(
      urgent: Color.lerp(urgent, other.urgent, t)!,
      high: Color.lerp(high, other.high, t)!,
      normal: Color.lerp(normal, other.normal, t)!,
      low: Color.lerp(low, other.low, t)!,
    );
  }
}
