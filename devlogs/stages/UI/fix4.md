我看完你改后的代码了，问题基本不在数据层，而在 **拖拽入口被改窄了**，再加上 `ReorderableListView` 和你自加的 `LongPressDraggable` 形成了手势竞争，导致“看起来整条 tile 都不能拖”。

## 主要问题定位

### 1. 组内拖拽现在只绑在很小的图标上

在 `widgets/todo_group_section.dart` 里，组内排序只靠这一段：

```dart
ReorderableDragStartListener(
  index: index,
  child: const Padding(
    child: Icon(Icons.drag_indicator, size: 22),
  ),
)
```

这意味着只有左边那个小图标能启动组内拖拽。
如果你实际操作时是拖 tile 本体，那一定拖不动。

### 2. 跨组拖拽也只绑在右侧小图标上

跨组拖拽现在是：

```dart
LongPressDraggable<TodoDragData>(
  child: const Padding(
    child: Icon(Icons.open_with, size: 22),
  ),
)
```

也就是说，**只有右边这个小图标可拖**。
tile 本体并不是跨组拖拽目标，所以你会感觉“整个 tile 都不能拖”。

### 3. 你现在把两种拖拽都做成“图标级手柄”，用户很容易以为功能失效

这是体验层面的实际问题。
功能不是完全坏了，而是入口太窄，且两套手势分散在不同位置，容易误判为“不能拖”。

---

# 本地 agent 的修改建议

## 修改目标

保留你当前的最小改动思路，但把拖拽入口恢复成：

* **组内拖拽：拖整条 tile 的主体区域**
* **跨组拖拽：保留右侧单独的小手柄**
* **不要让 `TodoItemCard` 自己再参与拖拽逻辑**

这样最稳，也最符合“组内拖放 + 最小变动跨组拖放”的实现。

---

## 实际修改步骤

### 步骤 1：把组内拖拽从“小图标”改成“整条 tile 主体”

修改文件：

* `lib/widgets/todo_group_section.dart`

在 `_TodoGroupBodyState.itemBuilder` 里，把现在左侧这个：

```dart
ReorderableDragStartListener(
  index: index,
  child: const Padding(
    padding: EdgeInsets.fromLTRB(4, 12, 6, 12),
    child: Icon(Icons.drag_indicator, size: 22),
  ),
),
Expanded(
  child: TodoItemCard(...),
),
```

改成：

```dart
Expanded(
  child: ReorderableDelayedDragStartListener(
    index: index,
    child: TodoItemCard(
      todo: todo,
      showCategoryChip: false,
      compact: true,
      subdued: false,
    ),
  ),
),
```

然后把左侧那个 `ReorderableDragStartListener` 整块删掉。

这样组内拖拽就能从 tile 主体直接长按启动，用户不会再觉得“拖不了”。

---

### 步骤 2：把跨组拖拽保留成右侧独立手柄

仍然在 `todo_group_section.dart`，保留右侧这个：

```dart
LongPressDraggable<TodoDragData>(
  data: TodoDragData(...),
  child: const Padding(
    padding: EdgeInsets.fromLTRB(6, 12, 4, 12),
    child: Icon(Icons.open_with, size: 22),
  ),
)
```

但建议补两个细节：

1. 给 `childWhenDragging` 保留占位，避免布局跳动
2. 给 `feedback` 稍微加宽一点，便于拖拽时视觉清晰

---

### 步骤 3：让 `TodoItemCard` 只负责显示和点击，不负责拖拽

修改文件：

* `lib/widgets/todo_item_card.dart`

检查这里不要再加任何拖拽相关包裹，比如：

* `LongPressDraggable`
* `ReorderableDragStartListener`
* `GestureDetector` 包整卡拖拽

`TodoItemCard` 应保持纯展示组件，只保留：

* 点击打开详情/操作
* 勾选完成
* 标签/提醒/优先级交互

拖拽入口交给 `todo_group_section.dart` 管。

---

### 步骤 4：把 `onReorderWithinGroup` 调用改成“非阻塞”

还是在 `todo_group_section.dart` 里，`ReorderableListView.builder` 的 `onReorder` 里不要直接 `await` 重数据库操作，改成：

```dart
onReorder: (oldIndex, newIndex) {
  debugPrint('intra-group onReorder called: $oldIndex -> $newIndex');
  unawaited(widget.onReorderWithinGroup(oldIndex, newIndex));
},
```

原因是 `ReorderableListView` 的拖拽动画依赖快速完成局部 UI 变更。
如果这里同步等待太久，拖拽感会很差，甚至让人误以为拖不动。

---

### 步骤 5：检查 `isManualSortEnabled` 的分支

现在 `_TodoGroupBody` 里只有在：

```dart
if (widget.isCompletedAggregate) ...
if (!widget.isManualSortEnabled) ...
```

这两个分支都不走时，才会进入 `ReorderableListView.builder`。

所以本地 agent 要确认：

* 当前排序字段是不是 `TodoSortField.manual`
* 如果不是，tile 本来就不会拖

如果你希望“只要显示在列表里就能拖”，那就要取消这个限制。
如果你希望只在手动排序模式下拖，那就保留这个限制，但要在 UI 上明确提示“当前排序模式不可拖拽”。

---

# 推荐的最终结构

最终建议你把 `_TodoGroupBody` 的 item 结构改成这样：

```dart
return Padding(
  key: ValueKey(todo.id),
  padding: EdgeInsets.only(bottom: isLastItem ? 0 : 4),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: ReorderableDelayedDragStartListener(
          index: index,
          child: TodoItemCard(
            todo: todo,
            showCategoryChip: false,
            compact: true,
            subdued: false,
          ),
        ),
      ),
      if (!widget.isCompletedAggregate)
        LongPressDraggable<TodoDragData>(
          data: TodoDragData(
            todoId: todo.id,
            sourceCategoryId: widget.categoryId,
            sourceGroupKey: widget.groupKey,
            sourceIndex: index,
          ),
          feedback: ...,
          childWhenDragging: ...,
          child: ...,
        ),
    ],
  ),
);
```

这个改法的好处是：

* 组内拖拽变成“拖整张卡片”，体验自然
* 跨组拖拽仍然是单独手柄，不会和组内 reorder 打架
* `TodoItemCard` 仍然保持纯 UI 组件，后续好维护

---

# 你本地 agent 应该优先检查的 3 个点

1. `todo_group_section.dart` 里是否还在用小图标做组内拖拽入口
2. `TodoItemCard` 有没有被外层再包一层拖拽组件
3. 当前排序字段是不是 `manual`，否则拖拽逻辑根本不会进 `ReorderableListView`

