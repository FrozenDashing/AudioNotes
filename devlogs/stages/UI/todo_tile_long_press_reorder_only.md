# Audionote 拖放重构方案：仅支持组内长按整条 Tile 拖动

## 目标

当前目标只保留一个能力：**在同一组内，长按整个 todo tile 进行拖动排序**。

本方案不包含跨组拖放，不包含删除式拖放，不包含额外拖拽手柄。

最终效果应满足：

1. 用户长按任意 todo tile 的主体区域即可开始拖动。
2. 拖动只发生在当前组内部，不允许跨组移动。
3. 视觉上整条 tile 是可拖动对象，而不是某个小图标。
4. 现有数据层、分组逻辑、排序逻辑尽量不改，只改 UI 拖拽入口和回调接线。
5. 为后续动画优化保留稳定 key、稳定局部刷新边界。

---

## 设计原则

### 1. 只用 `ReorderableListView` 解决组内排序

`ReorderableListView` 天然适合列表内部重排。

不要再把 `LongPressDraggable`、`DragTarget`、`GestureDetector` 叠加到同一张 tile 上，否则会产生手势冲突，导致拖不动或只在极小区域可拖。

### 2. 拖拽入口只保留一个

本方案的拖拽入口是：

- `ReorderableDelayedDragStartListener`

它应该包住整条 tile 的可见主体，而不是只包一个 icon。

### 3. `TodoItemCard` 保持纯展示组件

`TodoItemCard` 只负责显示：

- 标题
- 标签
- 时间信息
- 完成状态
- 点击事件

不要让它自己再包拖拽逻辑。拖拽入口应由上层列表负责，这样最容易维护，也最不容易和后续动画冲突。

---

## 当前问题的根因

如果目前“整条 tile 不能拖”，通常是以下原因之一：

### 问题 A：拖拽只绑定在小图标上

典型表现是列表里只有左侧 drag icon 可以拖，拖 tile 主体无效。

### 问题 B：tile 外层没有真正的 `ReorderableDragStartListener`

如果 `ReorderableListView.builder` 开了 `buildDefaultDragHandles: false`，但 item 内部没有显式拖拽入口，那么列表就是不可拖状态。

### 问题 C：`TodoItemCard` 自己或其内部子组件拦截了手势

例如：

- 外层套了 `GestureDetector`
- 或者在 `TodoItemCard` 内部加入了拖拽包裹
- 或者多个拖拽组件叠加，导致手势竞争

### 问题 D：当前列表根本没进入手动排序模式

如果业务逻辑有 `manual sort` 分支控制，只有手动排序模式下才会启用 `ReorderableListView`，否则渲染为静态 `Column`，当然不可拖。

---

## 推荐实现方式

## 方案总览

1. 保留 `ReorderableListView.builder` 作为组内列表容器。
2. 禁用默认拖拽手柄：`buildDefaultDragHandles: false`。
3. 在每个 item 上包一层 `ReorderableDelayedDragStartListener`。
4. 让这个 listener 包住整张 tile 的主体区域。
5. 组内排序回调继续调用现有的 `reorderTodosInGroup(...)`。
6. 删除所有跨组拖放相关代码。
7. 删除所有额外的 `LongPressDraggable`、`DragTarget`、跨组 payload 模型使用。

---

# 文件级修改说明

## 1. `lib/widgets/todo_group_section.dart`

这是核心修改文件。

### 需要保留的内容

- `ReorderableListView.builder`
- `onReorder`
- `buildDefaultDragHandles: false`
- 组内 item 的 `ValueKey(todo.id)`
- 分组逻辑、完成态逻辑、展开收起逻辑

### 需要删除的内容

- 左右两侧所有拖拽小图标
- `ReorderableDragStartListener` 包在小图标上的写法
- `LongPressDraggable`
- `DragTarget`
- 跨组 drop 相关回调

### 正确写法

把整条 tile 包进 `ReorderableDelayedDragStartListener`，示例：

```dart
ReorderableListView.builder(
  shrinkWrap: true,
  physics: const NeverScrollableScrollPhysics(),
  buildDefaultDragHandles: false,
  itemCount: group.items.length,
  onReorder: (oldIndex, newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    debugPrint('Reorder in group ${group.groupKey}: $oldIndex -> $newIndex');

    await widget.onReorderWithinGroup(oldIndex, newIndex);
  },
  itemBuilder: (context, index) {
    final todo = group.items[index];

    return Padding(
      key: ValueKey(todo.id),
      padding: EdgeInsets.only(bottom: index == group.items.length - 1 ? 0 : 4),
      child: ReorderableDelayedDragStartListener(
        index: index,
        child: TodoItemCard(
          todo: todo,
          showCategoryChip: false,
          compact: true,
          subdued: false,
        ),
      ),
    );
  },
)
```

### 为什么用 `ReorderableDelayedDragStartListener`

它更适合“长按整个 tile 再拖动”的交互。

用户感知上更加自然，也更不容易与 `InkWell` 的点击手势冲突。

---

## 2. `lib/widgets/todo_item_card.dart`

这是纯展示组件，建议尽量保持无状态、无拖拽逻辑。

### 需要保留

- 文字展示
- checkbox
- 点击进入详情或编辑
- 标签显示
- 时间展示

### 需要避免

- 不要在这里加入 `LongPressDraggable`
- 不要在这里加入 `ReorderableDragStartListener`
- 不要再额外包一层会影响拖拽的 `GestureDetector`

### 建议约束

如果卡片内部有按钮、checkbox、标签 chip 等可点击元素，要确认它们不会吞掉长按整个卡片的拖拽意图。

一般来说，`ReorderableDelayedDragStartListener` 包住卡片主体即可，不需要再给卡片内部增加拖拽代码。

---

## 3. `lib/providers/app_providers.dart`

这里通常负责重排和更新数据。

### 确认点

`reorderTodosInGroup(...)` 必须满足：

1. 接收旧 index 和新 index。
2. 在内存态中先做局部调整。
3. 更新数据库中的排序字段。
4. 不要在拖拽结束后直接整表 `loadTodos()`，否则动画和拖拽手感会变差。

### 推荐逻辑

```dart
Future<void> reorderTodosInGroup(List<TodoItem> items, int oldIndex, int newIndex) async {
  if (oldIndex < newIndex) {
    newIndex -= 1;
  }

  final moved = items.removeAt(oldIndex);
  items.insert(newIndex, moved);

  // 仅更新受影响的排序字段
  await _todoRepository.updateOrderIndexes(items);

  // 这里尽量做局部 state 更新，而不是整表 reload
  state = AsyncValue.data(state.value!.copyWith(/* 局部更新结果 */));
}
```

如果当前实现里是先改数据库再 `loadTodos()`，可以先保留，但后续建议改成局部 patch，以便动画优化。

---

## 4. `lib/models/todo_drag_data.dart`

如果已经因为跨组拖放而引入了 `TodoDragData`，在“只保留组内拖动”的阶段可以先不使用它。

### 处理建议

- 如果没有其它模块依赖它，可以暂时删除。
- 如果项目里还有引用，先保留文件，但不要在当前拖拽链路中使用。

### 重点

这个阶段不要再让拖拽数据在 UI 层和业务层之间流转，组内排序只需要 index 和当前组内列表即可。

---

# 推荐的最小改动步骤

## 第一步：恢复“整条 tile 可长按拖动”

在 `todo_group_section.dart` 中：

- 删除左侧小拖拽图标
- 删除右侧跨组拖拽图标
- 删除所有 `LongPressDraggable`、`DragTarget`
- 让 `TodoItemCard` 整体包进 `ReorderableDelayedDragStartListener`

这是最关键的一步。

---

## 第二步：确认排序模式确实是 manual

如果代码里还有“非 manual 模式不渲染 ReorderableListView”的分支，要确认当前页面确实在手动排序模式下。

建议临时加一条日志：

```dart
debugPrint('Current sort field: ${settings.todoSortField}');
```

如果不是 manual，拖动是不会生效的。

---

## 第三步：确认 `onReorder` 被触发

在 `onReorder` 里打印日志：

```dart
debugPrint('onReorder fired: $oldIndex -> $newIndex');
```

如果日志不打印，说明拖拽入口没有生效。

如果日志打印了但 UI 不变，说明是数据更新逻辑的问题。

---

## 第四步：确认 `TodoItemCard` 没有吞掉手势

如果卡片内层有：

- `GestureDetector`
- `InkWell`
- `Checkbox`
- `IconButton`

要确认它们不会让整张卡完全无法长按启动拖动。

通常只要 `ReorderableDelayedDragStartListener` 放在最外层包裹卡片，问题就会少很多。

---

# 参考结构

下面是推荐的 item 结构：

```dart
return Padding(
  key: ValueKey(todo.id),
  padding: EdgeInsets.only(bottom: isLastItem ? 0 : 4),
  child: ReorderableDelayedDragStartListener(
    index: index,
    child: TodoItemCard(
      todo: todo,
      showCategoryChip: false,
      compact: true,
      subdued: false,
    ),
  ),
);
```

这就是“长按整个 tile 组内拖动”的最简洁实现。

---

# 不建议再做的事

1. 不要把 `LongPressDraggable` 留在 item 上。
2. 不要把 `DragTarget` 留在 group 上。
3. 不要同时存在“图标拖拽”和“整卡拖拽”两套入口。
4. 不要把 reorder 逻辑和跨组 move 逻辑混在一起。
5. 不要在拖拽回调里直接整页重载。

---

# 验收标准

当修改完成后，应该满足：

- 长按任意 todo tile 主体，能进入拖动状态。
- 拖动范围只在当前组内有效。
- 释放后顺序会更新。
- 不需要点小图标。
- 不依赖跨组拖放相关代码。
- 不会因为点击 checkbox 或普通 tap 而干扰拖动入口。

---

# 后续扩展建议

等组内长按拖动稳定后，再考虑后续优化：

1. 局部刷新，不整页 reload。
2. 拖动中的悬浮预览样式优化。
3. 拖拽结束时增加轻微位移动画。
4. 再考虑是否需要跨组拖放。

当前版本先把最核心的体验做稳：**长按整个 tile，组内拖动**。

