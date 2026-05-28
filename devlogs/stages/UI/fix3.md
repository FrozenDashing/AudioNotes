可以，这个目标非常适合你现在的 slot 架构，而且**不需要把视觉间隔做大**。
最稳的做法是：

> **视觉层只保留 4px 空隙；交互层用“真实 tile 的边缘 1/3”做软命中区；真正的 drop 仍然落到 slot 上。**

这样你会同时得到：

* 列表更紧凑
* 释放更容易命中
* 拖拽提示更自然
* 不会再回到“大空隙 + 难拖”的状态

---

# 一、最终要达到的交互效果

## 视觉上

* 两个 todo 之间默认只留 **4px**
* 看起来像轻微分隔，而不是明显空白

## 交互上

* 当拖到某个 tile 的**上 1/3**时，提示“放到上面”
* 当拖到某个 tile 的**下 1/3**时，提示“放到下面”
* 中间区域不强行提示，避免误触
* 松手时，真正插入到相应 slot

---

# 二、推荐的整体方案

你现在最稳的实现方式是分两层：

## 1）视觉层：`4px` slot

就是你现在的间隔，但缩小成固定 4px。

## 2）交互层：tile 边缘感知

每个真实 tile 自己做一个“边缘感知器”：

* 顶部 1/3：提示插入到前面
* 底部 1/3：提示插入到后面
* 中部：不提示，或者保持上一次提示状态

这样你不需要把 gap 做大，也能提高 drop 识别率。

---

# 三、建议你改成的结构

---

## 现在推荐的组内结构

```text
[DropSlot 4px]
[TodoItemCard]
[DropSlot 4px]
[TodoItemCard]
[DropSlot 4px]
[TodoItemCard]
...
```

但是：

* `DropSlot` 只负责视觉占位和真正 drop 接收
* `TodoItemCard` 外面再加一层 **边缘感知器**
* 边缘感知器负责告诉父级“当前应该高亮哪个 slot”

---

# 四、最关键的改法：把 `_TodoGroupBody` 改成 StatefulWidget

你现在 `_TodoGroupBody` 是 `StatelessWidget`，但这个交互需要一个局部状态：

* 当前高亮的是哪个插入位
* 当前悬停在上边缘还是下边缘

所以建议改成：

```dart
class _TodoGroupBody extends StatefulWidget {
  ...
}
```

然后在 State 里放：

```dart
int? _activeInsertIndex;
bool _hovering = false;
```

---

# 五、状态怎么用

## 1）默认状态

* `DropSlot` 只显示 4px 空隙

## 2）拖到某个 tile 上方 1/3

* 设置 `_activeInsertIndex = 当前 tile 的 index`
* 对应上方 slot 展开成 ghost

## 3）拖到某个 tile 下方 1/3

* 设置 `_activeInsertIndex = 当前 tile 的 index + 1`
* 对应下方 slot 展开成 ghost

## 4）离开时

* `_activeInsertIndex = null`
* slot 收回到 4px

---

# 六、具体代码思路

---

## A. `_TodoGroupBody` 的新骨架

建议你改成这样的组织方式：

```dart
class _TodoGroupBody extends StatefulWidget {
  final List<TodoItem> items;
  final String groupKey;
  final String? categoryId;
  final bool isCompletedAggregate;
  final bool isManualSortEnabled;
  final Future<void> Function(
    String todoId,
    String? targetCategoryId,
    int targetIndex, {
    String? sourceGroupKey,
    int? sourceIndex,
  }) onMoveItemToGroup;

  const _TodoGroupBody({
    super.key,
    required this.items,
    required this.groupKey,
    required this.categoryId,
    required this.isCompletedAggregate,
    required this.isManualSortEnabled,
    required this.onMoveItemToGroup,
  });

  @override
  State<_TodoGroupBody> createState() => _TodoGroupBodyState();
}
```

---

## B. `State` 里维护高亮 slot

```dart
class _TodoGroupBodyState extends State<_TodoGroupBody> {
  int? _activeInsertIndex;

  void _setActiveInsertIndex(int? index) {
    if (!mounted) return;
    setState(() {
      _activeInsertIndex = index;
    });
  }

  void _clearActiveInsertIndex() {
    if (!mounted) return;
    setState(() {
      _activeInsertIndex = null;
    });
  }
}
```

---

## C. 组内渲染顺序

推荐这样渲染：

```dart
@override
Widget build(BuildContext context) {
  final children = <Widget>[];

  for (var index = 0; index < widget.items.length; index++) {
    children.add(
      _GroupDropSlot(
        key: ValueKey('slot_$index'),
        groupKey: widget.groupKey,
        categoryId: widget.categoryId,
        insertIndex: index,
        isActive: _activeInsertIndex == index,
        onDrop: widget.onMoveItemToGroup,
      ),
    );

    children.add(
      _EdgeAwareTodoRow(
        key: ValueKey(widget.items[index].id),
        todo: widget.items[index],
        index: index,
        groupKey: widget.groupKey,
        categoryId: widget.categoryId,
        isCompletedAggregate: widget.isCompletedAggregate,
        isManualSortEnabled: widget.isManualSortEnabled,
        onHoverInsertIndex: _setActiveInsertIndex,
        onLeave: _clearActiveInsertIndex,
        onDrop: widget.onMoveItemToGroup,
      ),
    );
  }

  children.add(
    _GroupDropSlot(
      key: ValueKey('slot_${widget.items.length}'),
      groupKey: widget.groupKey,
      categoryId: widget.categoryId,
      insertIndex: widget.items.length,
      isActive: _activeInsertIndex == widget.items.length,
      onDrop: widget.onMoveItemToGroup,
    ),
  );

  return Column(children: children);
}
```

---

# 七、4px 视觉间隙的实现

---

## `_GroupDropSlot` 建议变成只占 4px

默认状态：

```dart
SizedBox(height: 4)
```

激活状态：

* 展开成一个小 ghost tile
* 高度 24~28

---

## 推荐写法

```dart
class _GroupDropSlot extends StatefulWidget {
  final String groupKey;
  final String? categoryId;
  final int insertIndex;
  final bool isActive;
  final Future<void> Function(
    String todoId,
    String? targetCategoryId,
    int targetIndex, {
    String? sourceGroupKey,
    int? sourceIndex,
  }) onDrop;

  const _GroupDropSlot({
    super.key,
    required this.groupKey,
    required this.categoryId,
    required this.insertIndex,
    required this.isActive,
    required this.onDrop,
  });

  @override
  State<_GroupDropSlot> createState() => _GroupDropSlotState();
}
```

---

## 在 builder 里：

```dart
@override
Widget build(BuildContext context) {
  final theme = Theme.of(context);

  return DragTarget<TodoDragData>(
    onWillAcceptWithDetails: (details) {
      return true;
    },
    onLeave: (_) {},
    onAcceptWithDetails: (details) async {
      await widget.onDrop(
        details.data.todoId,
        widget.categoryId,
        widget.insertIndex,
        sourceGroupKey: details.data.sourceGroupKey,
        sourceIndex: details.data.sourceIndex,
      );
    },
    builder: (context, candidateData, rejectedData) {
      final active = widget.isActive || candidateData.isNotEmpty;

      return AnimatedSize(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          height: active ? 26 : 4,
          margin: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: active
                ? theme.colorScheme.primary.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: active
                ? Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.35),
                    width: 1,
                  )
                : null,
          ),
          child: active
              ? Row(
                  children: [
                    const SizedBox(width: 10),
                    Icon(
                      Icons.drag_indicator,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '放到这里',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      );
    },
  );
}
```

---

# 八、关键：边缘 1/3 的命中逻辑

你要的“拖到真实 tile 边缘 1/3 就会有提示”，应该由 tile 边缘感知器来做。

---

## 新增 `_EdgeAwareTodoRow`

这个组件不负责真正接收 drop，它只负责：

* 监听拖到这个 tile 附近的情况
* 计算当前位置在 tile 的上 1/3 / 中 1/3 / 下 1/3
* 告诉父级要高亮哪个 slot

---

## 推荐思路

### 上 1/3

* 高亮当前 tile 前面的 slot

### 下 1/3

* 高亮当前 tile 后面的 slot

### 中 1/3

* 不显示提示，或者保持当前 slot

---

## 结构建议

```dart
class _EdgeAwareTodoRow extends StatefulWidget {
  final TodoItem todo;
  final int index;
  final String groupKey;
  final String? categoryId;
  final bool isCompletedAggregate;
  final bool isManualSortEnabled;
  final Future<void> Function(
    String todoId,
    String? targetCategoryId,
    int targetIndex, {
    String? sourceGroupKey,
    int? sourceIndex,
  }) onDrop;
  final ValueChanged<int?> onHoverInsertIndex;
  final VoidCallback onLeave;

  const _EdgeAwareTodoRow({
    super.key,
    required this.todo,
    required this.index,
    required this.groupKey,
    required this.categoryId,
    required this.isCompletedAggregate,
    required this.isManualSortEnabled,
    required this.onDrop,
    required this.onHoverInsertIndex,
    required this.onLeave,
  });

  @override
  State<_EdgeAwareTodoRow> createState() => _EdgeAwareTodoRowState();
}
```

---

## 里面用 `DragTarget` 做边缘检测

```dart
class _EdgeAwareTodoRowState extends State<_EdgeAwareTodoRow> {
  final GlobalKey _boxKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final card = TodoItemCard(
      todo: widget.todo,
      showCategoryChip: false,
      compact: true,
      subdued: widget.isCompletedAggregate,
    );

    if (!widget.isManualSortEnabled || widget.isCompletedAggregate) {
      return card;
    }

    return DragTarget<TodoDragData>(
      onWillAcceptWithDetails: (details) {
        final renderBox =
            _boxKey.currentContext?.findRenderObject() as RenderBox?;
        if (renderBox == null) return true;

        final local = renderBox.globalToLocal(details.offset);
        final h = renderBox.size.height;
        final topThird = h / 3;
        final bottomThird = h * 2 / 3;

        if (local.dy < topThird) {
          widget.onHoverInsertIndex(widget.index);
        } else if (local.dy > bottomThird) {
          widget.onHoverInsertIndex(widget.index + 1);
        } else {
          // 中间区域不强制提示；也可以保留上一次提示
        }

        return true;
      },
      onLeave: (_) {
        widget.onLeave();
      },
      onAcceptWithDetails: (details) async {
        final renderBox =
            _boxKey.currentContext?.findRenderObject() as RenderBox?;
        final local = renderBox == null
            ? Offset.zero
            : renderBox.globalToLocal(details.offset);

        final h = renderBox?.size.height ?? 0;
        final targetIndex = local.dy < h / 2 ? widget.index : widget.index + 1;

        await widget.onDrop(
          details.data.todoId,
          widget.categoryId,
          targetIndex,
          sourceGroupKey: details.data.sourceGroupKey,
          sourceIndex: details.data.sourceIndex,
        );
      },
      builder: (context, candidateData, rejectedData) {
        return Container(
          key: _boxKey,
          child: card,
        );
      },
    );
  }
}
```

---

# 九、这个设计为什么能同时满足你的两个目标

## 目标 1：间隔缩短到 4px

因为 slot 默认就只有 4px，高度不会撑开。

## 目标 2：命中更灵敏

因为 tile 自己的上 1/3 和下 1/3 会触发插入提示，所以不需要必须准确拖进那 4px 的缝。

---

# 十、最重要的规则：slot 负责“落点”，tile 负责“感知”

这是这套方案的核心。

## Slot

* 高度 4px
* 真正接收 drop
* 显示 ghost

## Tile

* 负责判断“我应该把 slot 高亮在上面还是下面”
* 负责更大范围的命中感知

---

# 十一、如果你想更稳一点，建议再加一个微调

---

## 给 slot 的高亮增加一点“吸附感”

比如当拖到 tile 边缘 1/3 时，不是立刻显示完整 ghost，而是：

1. 先显示一条细线
2. 经过 80~120ms 再展开成 ghost tile

这样会更柔和，减少误触视觉跳变。

### 实现方式

`AnimatedSwitcher` + `AnimatedSize` 就够了。

---

# 十二、你现在最该改的顺序

## 第一步

把 `_TodoGroupBody` 改成 `StatefulWidget`

## 第二步

加入 `_activeInsertIndex`

## 第三步

把 `_GroupDropSlot` 的默认高度改为 `4`

## 第四步

给每个 `TodoItemCard` 外面包一层 `_EdgeAwareTodoRow`

## 第五步

让边缘 1/3 决定高亮哪个 slot

## 第六步

确认 `onDrop` 最终调用的是 notifier 的重排方法

---

# 十三、最终你会得到什么效果

改完后会变成：

* 列表更紧凑
* 每个 tile 之间只有 4px 空隙
* 拖拽到 tile 上方 1/3 就会提示“插到前面”
* 拖拽到 tile 下方 1/3 就会提示“插到后面”
* 用户不需要精准瞄准窄缝
* 释放命中率明显提高
* 视觉仍然干净

---

# 十四、最简总结

你要的不是“把空隙做大”，而是：

> **用 4px 的视觉槽位保留紧凑感，用 tile 边缘 1/3 的感知区提高拖拽命中。**

这套方案最适合你现在的分组列表结构，也最容易继续扩展动画和排序逻辑。
