我已经阅读了你最新的 `todo_item_card.dart` 代码，针对 **Compact 和 Standard 布局下元信息（_buildMetaRow）与单行标题文本之间的间距过大** 的问题，这里给出详细的分析和修改建议。

---

# 问题分析

1. 在 `_buildCompactContent` 和 `_buildStandardContent` 中，标题和元信息之间的间距是由：

```dart
const SizedBox(height: 3),
```

硬编码控制的。

2. 元信息中的每个 `Chip` 组件内部又有 `padding` 和 `Row`/`Wrap` 布局，这会让 Compact 模式下的空间看起来比实际更宽。

3. `_buildMetaRow` 的 `Wrap` 使用了：

```dart
spacing: compact ? 3 : 4,
runSpacing: compact ? 1 : 2,
```

这个 `runSpacing` 会在 Compact 模式下增加元信息与标题的垂直间距。

4. `_buildTitleBlock` 中也使用了：

```dart
height: 28,
padding: const EdgeInsets.only(top: 2),
Transform.translate(offset: const Offset(0, 4))
```

在 `loweredTitle` 为 true 时，标题整体向下偏移，这增加了标题和元信息之间的视觉间距。

---

# 修改建议

为了让 **标题文本与元信息靠得更近**，可以从三处入手：

1. **调整 Column 的 SizedBox**

   * `_buildCompactContent` 和 `_buildStandardContent` 中：

```dart
const SizedBox(height: 3),
```

可以改为：

```dart
const SizedBox(height: 1), // 或 0
```

2. **调整 Wrap 的 runSpacing**

   * `_buildMetaRow` 的 Wrap：

```dart
runSpacing: compact ? 1 : 2,
```

可以改为：

```dart
runSpacing: compact ? 0 : 1,
```

3. **调整标题偏移**

   * `_buildTitleBlock` 中 `loweredTitle` 导致向下偏移 4px 的 `Transform.translate`。
     在 Compact / Standard 模式下，可以取消或缩小 offset：

```dart
child: Transform.translate(
  offset: const Offset(0, 2), // 原来是 4
```

或者直接去掉 Transform.translate：

```dart
child: Align(
  alignment: Alignment.bottomLeft,
  child: titleWidget,
),
```

---

# 代码示例

修改 `_buildCompactContent` 和 `_buildStandardContent`：

```dart
const SizedBox(height: 1), // 原来是 3
```

修改 `_buildMetaRow`：

```dart
return Wrap(
  spacing: compact ? 3 : 4,
  runSpacing: compact ? 0 : 1, // 原来 compact 是 1
  alignment: alignment,
  crossAxisAlignment: WrapCrossAlignment.center,
  children: displayChips,
);
```

修改 `_buildTitleBlock` 中 `Transform.translate`：

```dart
final shouldBottomAlign = loweredTitle &&
    maxLines == 1 &&
    !isRecognizing &&
    !(todo.taskState == TodoTaskState.failed && todo.errorMessage != null);

if (shouldBottomAlign) {
  return SizedBox(
    height: 28,
    child: Padding(
      padding: const EdgeInsets.only(top: 1), // 原来 2
      child: Align(
        alignment: Alignment.bottomLeft,
        child: titleWidget,
      ),
    ),
  );
}
```

---

# 总结

* **Compact 和 Standard 模式**主要通过减少 `SizedBox(height)` 和 Wrap `runSpacing` 来压缩垂直间距。
* 可选：缩小 `_buildTitleBlock` 的 `Transform.translate` offset。
* 这些修改不会影响 Expanded 模式，也不会改变左右布局。
* 修改后，标题文本与元信息会更紧凑，同时保留 tickbox 右侧固定位置。

---

如果你需要，我可以帮你生成一个 **直接可替换的 `TodoItemCard` Compact + Standard 布局优化版**，集成所有这些间距优化。

你希望我直接生成吗？
