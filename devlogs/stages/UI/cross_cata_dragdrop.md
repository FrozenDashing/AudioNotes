可以，最小变动的做法不是让 `ReorderableListView` 一把包掉所有拖放，而是把两种拖放职责拆开：

* **同组内排序**：交给 `ReorderableListView`
* **跨组移动**：保留你现有的 `TodoDragData + DragTarget + moveTodoToCategoryAtIndex`

这样改动最少，也最稳。因为 `ReorderableListView` 本身更适合“单列表内重排”，不适合直接承载“跨列表搬运”的拖放 payload。

## 结论先说

你现在这套代码里，跨组移动其实已经有基础了，主要还差一层“和 ReorderableListView 共存”的接线方式。最小改法是：

1. **每个组内部改成 `ReorderableListView.builder`**
2. **组外层再包一层 `DragTarget<TodoDragData>`**
3. **同组拖动走 `onReorder`**
4. **跨组拖动走 `LongPressDraggable<TodoDragData>` + `DragTarget`**
5. **业务层继续复用现成的**

   * `reorderTodosInGroup(...)`
   * `moveTodoToCategoryAtIndex(...)`

---

# 为什么不能只靠 `ReorderableListView`

这是关键点。

`ReorderableListView` 解决的是“列表内重排”，但它没有把“被拖动 item 的业务数据”直接暴露成一个可被外部 `DragTarget` 接收的 payload。
也就是说，**它天然不擅长跨组 drop**。

所以最小变动的稳定方案是：

* **组内排序**：`ReorderableListView`
* **跨组搬运**：单独保留一个轻量 `LongPressDraggable<TodoDragData>`

这不是重复造轮子，而是把两个能力拆清楚，避免手势冲突。

---

# 最小变动的改造范围

建议只动这几个地方：

## 1. `widgets/todo_group_section.dart`

这里是核心。

把当前“行级 DragTarget + 空隙 slot”那套，收缩成：

* 组外层：`DragTarget<TodoDragData>`
* 组内列表：`ReorderableListView.builder`

### 组内职责

* `onReorder(oldIndex, newIndex)`
* 直接调用 `onReorderWithinGroup(...)`

### 组外职责

* 接收来自其他组的拖拽
* 调用 `onMoveItemToGroup(...)`

---

## 2. `widgets/todo_item_card.dart`

这里建议只加一个**很小的跨组拖拽手柄**，不要整张卡都包 `LongPressDraggable`，否则会和 `ReorderableListView` 抢手势。

推荐做法：

* 卡片左侧或右侧加一个小图标按钮，比如 `Icons.open_with`
* 这个图标才是 `LongPressDraggable<TodoDragData>`
* `ReorderableListView` 的拖拽手柄仍然用于组内排序

这样两种拖拽不会打架。

---

## 3. `screens/home_screen.dart`

这里只需要把两个回调继续接到现成的 notifier：

* `onReorderWithinGroup -> todoListProvider.notifier.reorderTodosInGroup(...)`
* `onMoveItemToGroup -> todoListProvider.notifier.moveTodoToCategoryAtIndex(...)`

这部分你现在已经有了，基本不用大改。

---

## 4. `models/todo_drag_data.dart`

如果你现在这个模型已经有：

* `todoId`
* `sourceGroupKey`
* `sourceIndex`
* `sourceCategoryId`

那就不用改。
如果没有 `sourceCategoryId`，建议补上，但不是必须。

---

# 具体实现策略

## A. 同组内拖拽：只用 `ReorderableListView`

每个 group 自己管自己的排序，不要再让每个 item 都独立处理 reorder 逻辑。

### 核心原则

* `ReorderableListView` 只负责 **同组内**
* `onReorder` 只改本组数组顺序
* 不要在 `onReorder` 里触发整页重载

### 示例结构

```dart
class TodoGroupSection extends StatelessWidget {
  final TodoGroup group;
  final bool isManualSortEnabled;
  final Future<void> Function(int oldIndex, int newIndex) onReorderWithinGroup;
  final Future<void> Function(
    String todoId,
    String? targetCategoryId,
    int targetIndex, {
    String? sourceGroupKey,
    int? sourceIndex,
  }) onMoveItemToGroup;

  const TodoGroupSection({
    super.key,
    required this.group,
    required this.isManualSortEnabled,
    required this.onReorderWithinGroup,
    required this.onMoveItemToGroup,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<TodoDragData>(
      onWillAcceptWithDetails: (details) {
        // 只接收“跨组”拖拽
        return details.data.sourceGroupKey != group.groupKey;
      },
      onAcceptWithDetails: (details) async {
        await onMoveItemToGroup(
          details.data.todoId,
          group.categoryId,
          group.items.length, // 默认插到组尾；也可以做成 slot 精准插入
          sourceGroupKey: details.data.sourceGroupKey,
          sourceIndex: details.data.sourceIndex,
        );
      },
      builder: (context, candidateData, rejectedData) {
        return ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          itemCount: group.items.length,
          onReorder: (oldIndex, newIndex) {
            onReorderWithinGroup(oldIndex, newIndex);
          },
          itemBuilder: (context, index) {
            final todo = group.items[index];
            return TodoItemCard(
              key: ValueKey(todo.id),
              todo: todo,
              index: index,
              groupKey: group.groupKey,
              isManualSortEnabled: isManualSortEnabled,
              enableCrossGroupDrag: true,
            );
          },
        );
      },
    );
  }
}
```

---

## B. 跨组拖拽：只给“一个小手柄”挂 `LongPressDraggable`

这里是最关键的最小变动点。

### 为什么不包整卡

因为整卡一旦被 `LongPressDraggable` 包住：

* 会和 `ReorderableListView` 冲突
* 手势优先级不好控
* 组内 reorder 容易失效或抖动

### 推荐方式

在 `TodoItemCard` 里加一个小拖拽 handle：

```dart
class TodoItemCard extends StatelessWidget {
  final TodoItem todo;
  final int index;
  final String groupKey;
  final bool isManualSortEnabled;
  final bool enableCrossGroupDrag;

  const TodoItemCard({
    super.key,
    required this.todo,
    required this.index,
    required this.groupKey,
    required this.isManualSortEnabled,
    this.enableCrossGroupDrag = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Row(
        children: [
          if (isManualSortEnabled)
            ReorderableDragStartListener(
              index: index,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(Icons.drag_handle),
              ),
            ),

          Expanded(
            child: _TodoContent(todo: todo),
          ),

          if (enableCrossGroupDrag)
            LongPressDraggable<TodoDragData>(
              data: TodoDragData(
                todoId: todo.id,
                sourceGroupKey: groupKey,
                sourceIndex: index,
                sourceCategoryId: todo.categoryId,
              ),
              feedback: Material(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: _TodoDragPreview(todo: todo),
                ),
              ),
              childWhenDragging: const Opacity(
                opacity: 0.3,
                child: Icon(Icons.open_with),
              ),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(Icons.open_with),
              ),
            ),
        ],
      ),
    );
  }
}
```

### 这个结构的好处

* 左边手柄：组内排序
* 右边手柄：跨组移动
* 两种拖拽互不抢事件

这是最稳的最小改动路线。

---

# 现有业务层基本可以直接复用

你现在 `TodoListNotifier` 里已经有这两个关键方法：

* `reorderTodosInGroup(...)`
* `moveTodoToCategoryAtIndex(...)`

所以跨组拖拽不需要重写数据库逻辑，只要接 UI 事件就行。

## 组内拖拽

调用：

```dart
await ref.read(todoListProvider.notifier).reorderTodosInGroup(
  group.items,
  oldIndex,
  newIndex,
);
```

## 跨组拖拽

调用：

```dart
await ref.read(todoListProvider.notifier).moveTodoToCategoryAtIndex(
  todoId,
  targetCategoryId,
  targetIndex,
  sourceGroupKey: sourceGroupKey,
  sourceIndex: sourceIndex,
);
```

这很好，说明你的数据层已经足够支撑这个方案。

---

# 你现在最该避免的坑

## 1. 不要让 `ReorderableListView` 和整卡 `LongPressDraggable` 同时作用在同一块区域

这是最容易出问题的地方。

## 2. 不要在跨组 drop 时重新 `loadTodos()`

那样动画会抖，列表也会闪。
尽量继续用你现在 notifier 里的局部更新方式。

## 3. 不要把跨组 drop 逻辑塞进 `onReorder`

`onReorder` 只负责同组内部排序，职责不要混。

## 4. 不要新增一套新的 group model

现在的 `categoryId + groupKey + status` 已经够用了。
先别再加新的层级，避免后面维护成本上升。

---

# 推荐的落地顺序

1. **先把组内拖拽改成 `ReorderableListView`**
2. **再给组外层加 `DragTarget<TodoDragData>`**
3. **最后给卡片加一个小的跨组拖拽手柄**
4. **确认 `moveTodoToCategoryAtIndex(...)` 可直接工作**
5. **补上拖拽中的高亮和落点反馈**

---

# 一句话版方案

**同组内用 `ReorderableListView`，跨组移动用独立的 `LongPressDraggable + DragTarget`，两者共用现成的 notifier 方法，不改数据库，不改分组模型，只改 UI 接线。**

我可以继续帮你把这套方案整理成一份“可直接交给接手 AI 的修改清单 + 代码模板”，按文件逐个标注该删什么、该加什么。
