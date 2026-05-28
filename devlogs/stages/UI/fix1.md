我已经能比较明确地判断：**这次“拖拽后又回原位”的问题，主要不在 UI，而在 `TodoListNotifier` 的拖拽落地逻辑**。

你现在的 slot / ghost 结构本身是对的。
真正的问题是：**拖拽完成后，顺序没有以“当前 state”为准先落地，再持久化；而是靠数据库重载回来。**
只要数据库顺序、查询排序、状态更新三者有任何一处不一致，就会出现你看到的“弹回原位”。

---

# 先给结论：你现在最该改的地方

## 最关键的 3 个点

1. **拖拽后先更新内存 state，不要先 `loadTodos()`**
2. **同组拖拽和跨组拖拽最好拆成两个方法**
3. **拖拽后要重写受影响组的 `orderIndex`，不能只改一条**

---

# 从你这份 `TodoListNotifier` 里，我看到的具体问题

---

## 问题 1：`moveTodoToCategoryAtIndex()` 结尾直接 `loadTodos()`

你现在最后是：

```dart
final dbHelper = ref.read(databaseHelperProvider);
await dbHelper.updateOrderIndices(orderMap);
await loadTodos();
```

这就是最容易导致“回弹”的地方。

### 为什么

因为你现在拖拽完成后：

* UI 先显示你拖过去了
* 然后又立刻从数据库重拉一次
* 如果数据库里的顺序没有完全按你拖拽结果稳定写进去，UI 就会回原位

### 正确做法

拖拽完成后应该先：

1. 在 `state` 里立即更新顺序
2. 再异步写数据库
3. **不要马上 `loadTodos()`**

也就是说，拖拽路径应该走“乐观更新”。

---

## 问题 2：`moveTodoToCategoryAtIndex()` 把“跨组移动”和“组内重排”混在一起了

你这段方法同时处理：

* 同组内重排
* 跨组移动

这会让逻辑变复杂，也容易有边界问题。

### 更稳的设计

拆成两个方法：

#### A. `reorderTodosInGroup(...)`

只负责**同组内排序**

#### B. `moveTodoToCategoryAtIndex(...)`

只负责**跨组移动**

这样你就不会在一个方法里同时判断：

* sourceGroupKey
* sourceIndex
* targetCategoryId
* sameGroupByCategory
* sameGroup

这类逻辑现在已经有点重了。

---

## 问题 3：你现在的重排逻辑不是“先改内存再持久化”

你现在拖拽完成后虽然更新了 `orderMap`，但没有先把当前展示列表同步成新顺序。

### 这意味着

即使数据库正确写了，UI 也容易因为 `loadTodos()` 的重新构建而出现短暂回弹。

### 正确顺序应该是

1. 先在 notifier 的 `state.value` 上重排
2. 立刻 `state = AsyncValue.data(reorderedList)`
3. 再把 `orderIndex` 写回数据库
4. 不要马上 reload 全量列表

---

# 你现在最应该怎么改

---

## 方案 A：最稳，推荐

### 同组拖拽时，直接走 `reorderTodosInGroup`

你现在 `TodoGroupSection` 的 slot 拖拽已经能拿到：

* `sourceGroupKey`
* `sourceIndex`
* `targetCategoryId`
* `targetIndex`

所以你在 notifier 层可以这样分流：

### 如果是同组

调用：

```dart
reorderTodosInGroup(...)
```

### 如果是跨组

调用：

```dart
moveTodoToCategoryAtIndex(...)
```

这样更清晰，也更不容易回弹。

---

## 方案 B：保留一个方法，但必须先更新 state

如果你不想拆方法，那至少要把 `moveTodoToCategoryAtIndex()` 改成：

### 流程

1. 读取 `state.value`
2. 在内存中计算新顺序
3. `state = AsyncValue.data(reorderedTodos)`
4. 更新 `orderIndex`
5. 保存数据库
6. 不要 `loadTodos()`

---

# 你的 `reorderTodosInGroup()` 也有问题

这个方法虽然看起来像是“组内重排”的正确路径，但它现在最后也是：

```dart
await dbHelper.updateOrderIndices(orderMap);
await loadTodos();
```

这还是会有回弹风险。

---

## 建议把它改成这样

### 先更新 state

比如：

```dart
state = AsyncValue.data(updatedItems);
```

### 再持久化数据库

```dart
await dbHelper.updateOrderIndices(orderMap);
```

### 不要立即 `loadTodos()`

除非你是在 debug 阶段想强制校验数据库。

---

# 你现在最可能的真实原因

结合你贴出来的代码，我认为**最有可能的原因是这两个同时存在**：

## 1. 你拖拽后没有先把 `state` 的顺序改掉

导致 UI 只是“临时显示”，一重建就恢复。

## 2. 你拖拽后又 `loadTodos()` 了

而 `loadTodos()` 读出来的顺序还是数据库旧状态，或者还没和当前拖拽顺序完全对齐。

---

# 你应该改成什么样的落地规则

---

## 规则 1：拖拽排序只在 manual 模式下生效

你现在这部分是对的，继续保留：

```dart
final isManualSortEnabled = settings.todoSortField == TodoSortField.manual;
```

如果不是 manual，就不要让拖拽进入 reorder 逻辑。

---

## 规则 2：同组重排时，不要重新查数据库来决定当前顺序

应该直接基于：

* 当前 `state.value`
* 当前 `group.items`

来做顺序重排。

不要每次拖完都去：

```dart
_repository.getAllTodos(sortByOrder: true)
```

因为这个会让你回到“数据库快照”，而不是“当前 UI 顺序”。

---

## 规则 3：重排完成后，先改 state，再写库

这是最关键的一条。

---

# 我建议你把 `moveTodoToCategoryAtIndex()` 改成这种思路

下面是逻辑，不是完整代码，但这是正确方向：

```dart
Future<void> moveTodoToCategoryAtIndex(
  String id,
  String? targetCategoryId,
  int targetIndex, {
  String? sourceGroupKey,
  int? sourceIndex,
}) async {
  final current = state.value ?? await _repository.getTodos(_queryOptions);
  final items = List<TodoItem>.from(current);

  final movingIndex = items.indexWhere((t) => t.id == id);
  if (movingIndex == -1) return;

  final movingTodo = items.removeAt(movingIndex);

  final sameGroup = movingTodo.categoryId == targetCategoryId;

  if (sameGroup && sourceIndex != null && sourceIndex < targetIndex) {
    targetIndex -= 1;
  }

  final updatedMoving = movingTodo.copyWith(categoryId: targetCategoryId);

  // 先在内存里插入
  final targetGroupItems = items
      .where((todo) => todo.categoryId == targetCategoryId)
      .toList();

  targetGroupItems.insert(
    targetIndex.clamp(0, targetGroupItems.length),
    updatedMoving,
  );

  // 重新编 orderIndex
  final orderMap = <String, int>{};
  for (var i = 0; i < targetGroupItems.length; i++) {
    orderMap[targetGroupItems[i].id] = i;
  }

  // 立即更新 UI
  state = AsyncValue.data(_rebuildListWithNewOrder(items, targetGroupItems));

  // 再写库
  await _repository.updateCategory(id, targetCategoryId);
  await ref.read(databaseHelperProvider).updateOrderIndices(orderMap);

  // 不要立刻 loadTodos()
}
```

---

# 你现在最实用的修复建议

## 第一刀：删掉拖拽路径里的 `await loadTodos()`

尤其是这两个方法：

* `moveTodoToCategoryAtIndex`
* `reorderTodosInGroup`

先把它们末尾的 `loadTodos()` 去掉，改成直接更新 `state`。

---

## 第二刀：同组拖拽不要走跨组方法

在 `TodoGroupSection` 的 drop 逻辑里判断：

* 如果 `sourceGroupKey == targetGroupKey`，直接调用组内重排方法
* 否则才调用跨组移动方法

这样更稳定。

---

## 第三刀：组内重排后重写该组所有 `orderIndex`

不要只改一个条目。

---

# 怎么快速验证问题是不是这个

你可以加 4 个日志：

## 1. drop 时

打印：

* sourceGroupKey
* sourceIndex
* targetCategoryId
* targetIndex

## 2. notifier 方法里

打印拖拽后的新顺序 id 列表

## 3. `updateOrderIndices` 后

打印写进数据库的 orderMap

## 4. `loadTodos()` 前后

打印数据库重新读出的顺序

---

## 判断标准

### 如果：

* notifier 里顺序变了
* 数据库也变了
* 但 `loadTodos()` 后又回原位

说明就是**reload 的数据源顺序和拖拽顺序冲突**。

### 如果：

* notifier 里顺序没变
* 数据库也没变

说明是**重排逻辑根本没真正落地**。

---

# 我对你当前代码的直接判断

从你贴的代码看，**最该改的不是 `TodoGroupSection`，而是 `TodoListNotifier` 的拖拽落地策略**。

你的 UI 现在已经能拖，说明 slot 思路是对的。
真正的问题是：

> **拖拽结果没有先进入 notifier 的当前 state，就被 `loadTodos()` 冲掉了。**

---

# 最后给你一个最稳的开发顺序

## 1. 先把拖拽方法改成“先改 state，再写库”

这是第一优先级。

## 2. 同组拖拽和跨组移动拆开

减少条件分支。

## 3. 去掉拖拽后立即 `loadTodos()`

这是回弹的高风险点。

## 4. manual 模式以外禁用拖拽

避免排序条件覆盖拖拽结果。


