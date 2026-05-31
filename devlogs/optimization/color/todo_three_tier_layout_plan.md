# TodoItemCard 优先级颜色与 Checkbox Tick 色修改方案（暗化主题色版）

## 一、总体计划

目标：
1. 优先级颜色统一管理（Urgent / High / Normal / Low）。
2. Checkbox 勾选颜色随主题色变化，但默认颜色比主题主色稍暗。
3. 保持现有 chip 样式体系，不破坏布局和现有逻辑。

## 二、优先级颜色

推荐色号：
- 紧急 / Urgent：#E5484D
- 高 / High：#F97316
- 中 / Normal：#3B82F6
- 低 / Low：#22C55E

深色模式可用深色版本稍微减亮：
- 紧急：#FF6B6B
- 高：#FFB86B
- 中：#7AB8FF
- 低：#6EE7A8

### ThemeExtension 实现
```dart
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
  TodoPriorityPalette copyWith({Color? urgent, Color? high, Color? normal, Color? low}) => TodoPriorityPalette(
    urgent: urgent ?? this.urgent,
    high: high ?? this.high,
    normal: normal ?? this.normal,
    low: low ?? this.low,
  );

  @override
  TodoPriorityPalette lerp(ThemeExtension<TodoPriorityPalette>? other, double t) {
    if (other is! TodoPriorityPalette) return this;
    return TodoPriorityPalette(
      urgent: Color.lerp(urgent, other.urgent, t)!,
      high: Color.lerp(high, other.high, t)!,
      normal: Color.lerp(normal, other.normal, t)!,
      low: Color.lerp(low, other.low, t)!,
    );
  }
}
```

挂到主题：
```dart
theme: ThemeData(
  colorScheme: lightColorScheme,
  extensions: const [
    TodoPriorityPalette(
      urgent: Color(0xFFE5484D),
      high: Color(0xFFF97316),
      normal: Color(0xFF3B82F6),
      low: Color(0xFF22C55E),
    ),
  ],
)
```

## 三、优先级颜色解析器
```dart
PriorityColors resolvePriorityColor(BuildContext context, TodoPriority priority) {
  final palette = Theme.of(context).extension<TodoPriorityPalette>()!;
  switch (priority) {
    case TodoPriority.urgent: return PriorityColors(palette.urgent);
    case TodoPriority.high: return PriorityColors(palette.high);
    case TodoPriority.normal: return PriorityColors(palette.normal);
    case TodoPriority.low: return PriorityColors(palette.low);
  }
}
```

## 四、Checkbox Tick 色修改

### 4.1 默认颜色比主题主色暗一点
- 获取主题色：`theme.colorScheme.primary`
- 调暗约 15-20%：`primary.withOpacity(0.85)` 或者 HSL/HSV 调整亮度
- CheckColor 可用主题 onPrimary

### 4.2 代码示例
```dart
final theme = Theme.of(context);
final tickColor = theme.colorScheme.primary.withOpacity(0.85); // 稍暗

Checkbox(
  value: todo.status == TodoStatus.completed,
  onChanged: (value) => _setStatus(...),
  activeColor: tickColor,
  checkColor: theme.colorScheme.onPrimary,
)
```

如果希望全局统一，可通过 `CheckboxThemeData` 设置：
```dart
CheckboxThemeData(
  fillColor: MaterialStateProperty.resolveWith((states) {
    if (states.contains(MaterialState.selected)) {
      return theme.colorScheme.primary.withOpacity(0.85);
    }
    return theme.colorScheme.outlineVariant;
  }),
  checkColor: MaterialStateProperty.all(theme.colorScheme.onPrimary),
)
```

## 五、落点总结

- 优先级 chip 与主题无关，保持语义色彩
- Checkbox tick color 跟随主题主色，但稍微调暗
- 保持原 chip 背景/边框逻辑
- 不破坏现有布局
- 支持浅色 / 深色 / 自定义主题自动联动

这样实现后，你的 TodoItemCard 在不同主题下，优先级颜色和 tickbox tick 都会统一风格，视觉层次清晰且自然。

