下面给你一份**可以直接按文件改的详尽草案**，目标是把你现在这套结构升级成：

* **slot 式占位**
* **轻量 drag preview**
* **TodoItemCard 变轻**
* **组内拖拽逻辑长期可扩展**
* **减少重建次数**
* **避免虚拟 tile 错位**

我会尽量贴着你现有的 `TodoGroupSection.dart`、`HomeScreen.dart`、`TodoItemCard.dart` 来写。

---

# 一、先给结论：这次重构的正确方向

你现在最稳的结构应该变成这样：

```text
HomeScreen
 └─ TodoGroupSection
     ├─ GroupHeader
     └─ TodoGroupBody
         ├─ DropSlot(0)
         ├─ DraggableTodoRow(Item 0)
         ├─ DropSlot(1)
         ├─ DraggableTodoRow(Item 1)
         ├─ DropSlot(2)
         └─ ...
```

关键点是：

1. **占位不再画在 tile 里面**
2. **占位变成列表结构的一部分**
3. **拖拽反馈用轻量预览，不复用完整卡片**
4. **TodoItemCard 只负责“显示”**
5. **拖拽 wrapper 放到组内 body，而不是卡片内部**

---

# 二、你现在这版为什么会错位

你现在的 `_TileDropTarget` 是这种思路：

* 监听拖到某个卡片上
* 判断在上半区还是下半区
* 在该卡片内部 `Stack + Positioned` 画一个提示块

这会错位，原因有四个：

## 1. 你依赖卡片内部高度

而你的 `TodoItemCard` 高度不是固定的，受这些因素影响：

* 是否 compact
* 是否 recognizing
* 是否 completed
* 标签数量
* 文本是否换行

所以用 `centerY` 去猜插入位置天然不稳。

## 2. `Positioned(top: -37)` 是硬编码

这对不同卡片高度、不同字体、不同系统缩放都不稳。

## 3. 你把占位叠在 tile 里

这会导致：

* 原卡片还在
* 占位块又出现
* 两层视觉竞争
* 看起来“偏”和“重影”

## 4. 你还复用了完整卡片作为拖拽源

拖拽时卡片本身又重、又有查询、又有交互，反馈会更慢。

---

# 三、最稳的总体重构方案

---

## 方案核心：slot-based placeholder

不要再让每个 tile 自己判断“上半区/下半区”。
改成**每个插入点本身就是一个 slot**。

也就是说，组内列表渲染时不是只画 item，而是画：

* slot 0
* item 0
* slot 1
* item 1
* slot 2
* item 2
* slot 3

这样拖到哪里，就把 ghost tile 放到哪个 slot 上。

---

# 四、文件级改造草案

---

## 1）`todo_drag_data.dart`：补充拖拽元数据

你现在的拖拽数据太少了。
建议把它升级成：

```dart
class TodoDragData {
  final String todoId;
  final String? sourceCategoryId;
  final String sourceGroupKey;
  final int sourceIndex;

  const TodoDragData({
    required this.todoId,
    required this.sourceCategoryId,
    required this.sourceGroupKey,
    required this.sourceIndex,
  });
}
```

### 为什么要加这些字段

* `sourceGroupKey`：用于判断是否同组拖拽
* `sourceIndex`：用于组内重排时做 index 修正
* `sourceCategoryId`：跨组拖拽时保留分类信息

---

## 2）`TodoItemCard.dart`：把拖拽逻辑剥离出去

这是最关键的一步。

### 现在的问题

`TodoItemCard` 里自己包了：

* `LongPressDraggable`
* `feedback`
* `childWhenDragging`

这会让卡片本身变成“拖拽源 + 展示层 + 交互层”。

### 推荐改法

让 `TodoItemCard` 变成**纯展示卡片**。

也就是把下面这整段拖拽包装从 `TodoItemCard` 里拿掉：

```dart
return LongPressDraggable<TodoDragData>(
  ...
);
```

### 改成什么

把它移动到 `TodoGroupBody` 里，由父级包一层 `LongPressDraggable`。

这样父级知道：

* 当前 item 的 index
* 当前 groupKey
* 当前 categoryId

而 `TodoItemCard` 只负责画卡片。

---

## 3）`TodoGroupSection.dart`：删掉 tile 内部占位逻辑，改成 slot 结构

你现在最该重写的是这两个类：

* `_TodoGroupBody`
* `_TileDropTarget`

---

# 五、建议的新结构

---

## A. `_TodoGroupBody` 改成 slot 列表

你现在是：

```dart
for (var index = 0; index < items.length; index++) {
  children.add(_TileDropTarget(...));
  if (index < items.length - 1) {
    children.add(const SizedBox(height: 4));
  }
}
```

这个结构保留了“每个 tile 一个 target”的旧思路，建议改成：

```dart
final children = <Widget>[];

for (var i = 0; i < items.length; i++) {
  children.add(
    _GroupDropSlot(
      key: ValueKey('slot_$i'),
      groupKey: groupKey,
      categoryId: categoryId,
      insertIndex: i,
      onDrop: onMoveItemToGroup,
    ),
  );

  children.add(
    _DraggableTodoRow(
      key: ValueKey(items[i].id),
      todo: items[i],
      index: i,
      groupKey: groupKey,
      categoryId: categoryId,
      isCompletedAggregate: isCompletedAggregate,
      isManualSortEnabled: isManualSortEnabled,
      onMoveItemToGroup: onMoveItemToGroup,
      onReorderWithinGroup: onReorderWithinGroup,
    ),
  );
}

children.add(
  _GroupDropSlot(
    key: ValueKey('slot_${items.length}'),
    groupKey: groupKey,
    categoryId: categoryId,
    insertIndex: items.length,
    onDrop: onMoveItemToGroup,
  ),
);
```

### 这样做的好处

* 插入位置就是 slot
* 不需要半区判断
* 不需要在 card 内部叠层
* 以后动画更好做
* 错位问题会明显减少

---

## B. 新增 `_GroupDropSlot`

这是替代 `_TileDropTarget` 的核心组件。

### 职责

* 作为“插入位置”
* 在拖拽悬停时显示 ghost tile
* 松手时把 todo 插入该 slot

### 建议结构

```dart
class _GroupDropSlot extends StatefulWidget {
  final String groupKey;
  final String? categoryId;
  final int insertIndex;
  final Future<void> Function(
    String todoId,
    String? targetCategoryId,
    int targetIndex,
  ) onDrop;

  const _GroupDropSlot({
    super.key,
    required this.groupKey,
    required this.categoryId,
    required this.insertIndex,
    required this.onDrop,
  });

  @override
  State<_GroupDropSlot> createState() => _GroupDropSlotState();
}
```

### 内部状态

```dart
class _GroupDropSlotState extends State<_GroupDropSlot> {
  bool _active = false;
```

### build 逻辑

```dart
@override
Widget build(BuildContext context) {
  final theme = Theme.of(context);

  return DragTarget<TodoDragData>(
    onWillAcceptWithDetails: (details) {
      // 拒绝把自己拖到自己对应的 slot（可选）
      if (details.data.sourceGroupKey == widget.groupKey &&
          details.data.sourceIndex == widget.insertIndex) {
        return false;
      }

      setState(() => _active = true);
      return true;
    },
    onLeave: (_) {
      setState(() => _active = false);
    },
    onAcceptWithDetails: (details) async {
      setState(() => _active = false);
      await widget.onDrop(
        details.data.todoId,
        widget.categoryId,
        widget.insertIndex,
      );
    },
    builder: (context, candidateData, rejectedData) {
      final isHovering = _active || candidateData.isNotEmpty;

      return AnimatedSize(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 140),
          child: isHovering
              ? _GhostInsertTile(
                  key: const ValueKey('ghost'),
                  theme: theme,
                  label: '放到这里',
                )
              : const SizedBox(
                  key: ValueKey('empty'),
                  height: 10,
                ),
        ),
      );
    },
  );
}
```

---

## C. 新增 `_GhostInsertTile`

这个就是你想要的“虚拟 tile”，但它不是卡片内部浮层，而是 slot 本身的视觉内容。

### 推荐样式

* 轻背景
* 虚线边框
* 圆角
* 比正常卡片更浅
* 高度适中，不要太高

### 例子

```dart
class _GhostInsertTile extends StatelessWidget {
  final ThemeData theme;
  final String label;

  const _GhostInsertTile({
    super.key,
    required this.theme,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.primary.withValues(alpha: 0.35),
            style: BorderStyle.solid,
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.drag_indicator,
              size: 18,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '插入这里',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

# 六、拖拽源应该怎么做

---

## 新增 `_DraggableTodoRow`

这个 wrapper 放在 `_TodoGroupBody` 里，负责把 `TodoItemCard` 变成拖拽源。

### 好处

* `TodoItemCard` 变纯 UI
* 拖拽 metadata 由父级传入
* 更容易控制 `sourceIndex` 和 `sourceGroupKey`

### 示例结构

```dart
class _DraggableTodoRow extends StatelessWidget {
  final TodoItem todo;
  final int index;
  final String groupKey;
  final String? categoryId;
  final bool isCompletedAggregate;
  final bool isManualSortEnabled;
  final Future<void> Function(
    String todoId,
    String? targetCategoryId,
    int targetIndex,
  ) onMoveItemToGroup;
  final Future<void> Function(int oldIndex, int newIndex) onReorderWithinGroup;

  const _DraggableTodoRow({
    super.key,
    required this.todo,
    required this.index,
    required this.groupKey,
    required this.categoryId,
    required this.isCompletedAggregate,
    required this.isManualSortEnabled,
    required this.onMoveItemToGroup,
    required this.onReorderWithinGroup,
  });

  @override
  Widget build(BuildContext context) {
    final card = TodoItemCard(
      todo: todo,
      showCategoryChip: false,
      compact: true,
      subdued: isCompletedAggregate,
    );

    if (!isManualSortEnabled || isCompletedAggregate) {
      return card;
    }

    return LongPressDraggable<TodoDragData>(
      data: TodoDragData(
        todoId: todo.id,
        sourceCategoryId: categoryId,
        sourceGroupKey: groupKey,
        sourceIndex: index,
      ),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      feedback: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: _TodoDragPreview(todo: todo),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.18,
        child: card,
      ),
      child: card,
    );
  }
}
```

---

# 七、拖拽预览应该怎么做

---

## 新增 `_TodoDragPreview`

这是你拖动时看到的“轻量卡片”。

### 设计原则

* 只保留视觉
* 不查数据库
* 不显示按钮
* 不显示 checkbox
* 不显示完整操作菜单

### 推荐内容

* 标题
* 优先级
* 时间（可选）
* 少量标签（可选，最好先不带）

### 示例

```dart
class _TodoDragPreview extends StatelessWidget {
  final TodoItem todo;

  const _TodoDragPreview({
    required this.todo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Opacity(
      opacity: 0.96,
      child: Container(
        width: 360,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(Icons.drag_indicator, color: theme.colorScheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                todo.text.isEmpty ? '识别中...' : todo.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

---

# 八、`TodoItemCard` 建议怎么瘦身

你现在的 `TodoItemCard` 可以保留：

* 文本
* 完成态
* 优先级标签
* 时间标签
* 分类/标签按钮
* 编辑菜单
* 播放/重录/删除

但建议去掉：

* `LongPressDraggable`
* 任何 drag feedback
* 任何插入位置逻辑
* `FutureBuilder` 查标签

---

## 1. 去掉整列表 watch

你现在有：

```dart
ref.watch(todoListProvider);
```

如果可以，尽量别让卡片直接 watch 整个列表。
短期可以先保留，但长期建议改成：

* 父级把必要状态传给卡片
* 卡片只读 `todo` 数据本身

---

## 2. 标签查询改为缓存

现在这段会拖慢构建：

```dart
FutureBuilder<List<Tag>>(
  future: ref.read(tagRepositoryProvider).getTagsForTodo(todo.id),
```

建议改成：

* `tagsByTodoIdProvider`
* 或在 `TodoListNotifier` 里统一组装

---

## 3. `Card.margin` 改成外层 `Padding`

这样拖拽预览和真实卡片更容易对齐。

---

# 九、`TodoGroupSection` 应该怎么改

---

## 1. 删除 `_displayItems`

你现在在 section 内保存：

* `_displayItems`

这让 section 自己承担了排序和数据缓存职责。
长期最稳的方式是：**直接用 `widget.group.items`**。

也就是说：

* 分组和排序交给 grouping service
* section 只渲染结果

---

## 2. 删除 `_ensureSortedAsync`

展开时再排序，会让 UI 和数据状态分离。
建议在：

* `TodoGroupingService.buildGroups(...)`

里把组内排序做好。

---

## 3. 保留局部展开状态

展开/折叠状态可以保留在 section 本地：

```dart
late bool _isExpanded;
```

但要注意：

* 只保存一份真值来源
* debounce 持久化
* 不再让 HomeScreen 和 section 各持有一份展开状态

---

# 十、`HomeScreen` 建议怎么改

---

## 1. 先把 `findAncestorStateOfType` 移出去

你现在在 build 里反复找 ancestor state，这不优雅，也不利于维护。

建议在 `build` 开头就取局部变量：

```dart
final groupOrderMap = _groupOrderMap;
final expandedGroups = _expandedGroups;
```

然后传给 `_TodoListContent(...)`。

---

## 2. 如果展开状态迁移到 section 本地，HomeScreen 只保留 group order

如果你按我上面的方向做，建议：

* `_expandedGroups` 以后可以移除
* 只保留 `_groupOrderMap`
* 展开状态在 section 内本地控制

这样状态就少很多。

---

# 十一、组内重排的 index 处理建议

这是一个容易忽略但很重要的点。

当你拖拽同组内的 item 时，**插入 index 需要按“删除源 item 后的列表”来修正**。

---

## 规则

如果：

* `sourceGroupKey == targetGroupKey`
* 并且 `sourceIndex < targetIndex`

那么真正插入时应该：

```dart
targetIndex -= 1;
```

否则会出现：

* 往后拖时插入位置偏一位

---

## 建议放在 notifier 或 repository 层统一处理

不要在 slot widget 里做这个逻辑。
slot 只负责把 `insertIndex` 传出去。

---

# 十二、长期最稳的版本，我建议你最终变成这样

---

## 1. 视图层

* `HomeScreen`
* `TodoGroupSection`
* `TodoGroupBody`
* `TodoItemCard`
* `DropSlot`
* `TodoDragPreview`

---

## 2. 状态层

* `TodoListNotifier`
* `SettingsNotifier`

---

## 3. 分组层

* `TodoGroupingService`
* `TodoGroup`

---

## 4. 数据层

* `TodoRepository`
* `CategoryRepository`
* `TagRepository`

---

# 十三、建议的实施顺序

如果你要一步步改，顺序建议这样排：

## 第一步

把 `TodoItemCard` 里的 `LongPressDraggable` 拿掉。

## 第二步

在 `_TodoGroupBody` 中新增 `_DraggableTodoRow`，把拖拽包装放父级。

## 第三步

把 `_TileDropTarget` 删除，替换成 `_GroupDropSlot`。

## 第四步

把占位逻辑改成 slot 渲染 ghost tile。

## 第五步

把 tags 查询缓存化，减少重建。

## 第六步

把 `_displayItems` 和 `_ensureSortedAsync` 删掉，让 grouping service 统一排序。

---

# 十四、最终验收标准

改完之后，你应该看到这些结果：

* 拖拽时的占位位置准确，不再偏
* 虚拟 tile 是插槽的一部分，而不是 tile 内部浮层
* 拖拽预览更轻，不会卡
* `TodoItemCard` 更纯，重建更少
* 组内排序和组外拖拽职责更清晰
* 后面加自动滚动、拖拽动画、组折叠动画都更容易

---

# 十五、可以直接照着动手的最小改造版摘要

如果你只记住一版最关键的修改，那就是：

1. **把拖拽 wrapper 从 `TodoItemCard` 挪到 `_TodoGroupBody`**
2. **把 `_TileDropTarget` 改成 `_GroupDropSlot`**
3. **把虚拟 tile 做成 slot 的 ghost 状态**
4. **把 feedback 改成轻量预览**
5. **把标签查询改缓存**
6. **把 section 内部排序逻辑收回 grouping service**

---

如果你下一条要继续，我可以直接给你一版**“接近可粘贴到项目里”的 Dart 代码草案**，我会按你现在这两个文件的结构，直接写出：

* `TodoDragData` 新定义
* `_DraggableTodoRow`
* `_GroupDropSlot`
* `_GhostInsertTile`
* `_TodoGroupBody` 新写法

这样你就能直接开始改。
