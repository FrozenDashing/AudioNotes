# Audionote APP 局部刷新方案（为动画优化做准备）

## 1. 目标

在当前已经实现组内拖拽 tile 的基础上，减少全局刷新次数，实现局部刷新，为后续添加动画效果打基础。

核心目标：

* 单条 todo 更新时只刷新该卡片或所属组
* 列表增删条目时只刷新受影响部分，不重建整组或全列表
* 避免 provider/StateNotifier 导致全局 rebuild
* 为拖拽动画提供稳定的 widget 树和 key

---

## 2. 核心思路

### 2.1 拆分状态

将整体 todo 列表状态拆分成几个层次：

1. **todo 数据层** (`todoDataProvider`) ：只存储待办条目本身
2. **分组状态层** (`groupedTodosProvider`) ：负责分组、排序计算，派生自 todo 数据层
3. **单条选中 / 编辑状态** (`todoItemStateProvider`) ：每个 tile 自己的局部状态
4. **摘要统计 / 工具条状态** (`todoSummaryProvider`) ：仅存储已完成/未完成数量等

这种拆分可以确保某条 todo 更新时只通知对应 tile，而不是整个列表刷新。

### 2.2 使用 stable `ValueKey`

* `TodoItemCard` 和 `ReorderableListView` 每个 item 使用 `ValueKey(todo.id)`
* 确保 Flutter 可以局部更新而不是重建整个 widget 树

### 2.3 局部刷新策略

* **单条更新**（如完成勾选、文字修改）

  * 更新 `todoDataProvider` 中对应 todo
  * `TodoItemCard` 通过独立 provider / ConsumerWidget 监听该 todo
  * 只有该卡片 rebuild

* **组内增删**

  * 更新 `groupedTodosProvider`，只 rebuild 受影响组
  * 使用 `ReorderableListView.builder` 的 itemBuilder 构建每个 tile，避免整个列表 rebuild

* **工具条 / 摘要**

  * 单独使用 `todoSummaryProvider`，只通知工具条刷新，不触发列表 rebuild

### 2.4 拖拽动画友好性

* `ReorderableDelayedDragStartListener` 包住整个 tile，tile key 保持稳定
* 拖拽过程中只有被拖动 tile 的 feedback widget 会漂浮，其余 tile 不重建
* 拖拽完成后，局部更新列表顺序即可，不 reload 整组

---

## 3. 文件级修改建议

### 3.1 `todo_group_section.dart`

* 每个组内部使用 `ReorderableListView.builder`
* `itemBuilder` 返回 `TodoItemCard` 外包 `ReorderableDelayedDragStartListener`
* 只 rebuild 改变的 tile，不 rebuild 整个组
* 删除所有跨组拖拽相关组件

### 3.2 `todo_item_card.dart`

* 保持纯展示组件
* 使用 `ConsumerWidget` 或 `HookConsumerWidget` 来监听对应 todo 数据
* 仅 tile 内部 state 改变时刷新
* 不要在卡片内部包拖拽逻辑

### 3.3 Providers（`app_providers.dart`）

* 拆分 provider：数据、单条状态、分组、摘要
* 在 `updateText` / `toggleComplete` / `updatePriority` 时只更新对应 todo 状态
* 删除或添加 todo 时只修改受影响的组状态
* 不要整表 reload，保证动画期间 widget 树稳定

### 3.4 工具条 / 摘要（`floating_action_toolbar.dart`）

* 单独使用摘要 provider
* 只监听已完成 / 未完成数量变化
* 不 watch 整个 todo 列表

---

## 4. 局部刷新实践建议

1. 每个 tile 的 key 使用 todo.id，避免 rebuild
2. 每条 todo 监听自己的 provider / state，不依赖整个列表
3. group rebuild 仅在组内 item 增删或排序时触发
4. 对 ReorderableListView，尽量使用 `builder` 而不是 `children` 列表
5. 拖拽动画期间不要触发全局 state 更新，只在拖拽完成时局部 patch
6. 工具条、摘要使用独立 provider，不依赖 todo 列表 state

---

## 5. 后续动画优化准备

* 保证每个 tile 的 widget 树稳定，key 不变
* 拖拽 feedback 独立 widget，不影响列表 rebuild
* 局部刷新后，动画可以应用于单个 tile 或组内 reorder
* 对于增删操作，可用 AnimatedList 或 implicit animations 做平滑过渡

---

## 6. 总结

通过拆分状态、使用局部 provider、稳定 key 和局部 rebuild，可以实现：

* 拖拽操作顺滑、动画友好
* 单条 todo 更新不会触发整列表重建
* 后续动画效果可直接在 tile 或组内实现
* 保留组内长按拖拽功能，并为跨组扩展留出接口
