# Category 分组视图下一阶段大改造执行文档

> 适用对象：刚接手这个项目的开发者 / AI
>
> 目标：在**保留当前 Flutter + Riverpod + SQLite + Vosk 代码基础设施**的前提下，把现有“平铺式待办列表”升级为**以 Category 为核心的分组视图**。  
> 这次改造不是重做项目，而是基于现有数据模型、Repository、Provider、设置系统和待办卡片，做一次结构性 UI 重构与排序规则重写。

---

# 0. 这次大改造的核心诉求

你现在要做的不是“再加一个功能点”，而是把待办列表从：

- 每条 Todo 单独显示

升级成：

- **Category 作为大分组**
- **没有 Category 的 Todo 自动归入“未分类”组**
- **组内 Todo 用虚线分隔**
- **Label 作为每条 Todo 的附加属性继续显示**
- **组本身支持拖拽排序**
- **组内 Todo 支持组内排序**
- **取消“按 Category 排序”的全局排序模式**
- **所有排序只作用于组内 Todo，不再作用于组之间**

这会带来两个最重要的变化：

1. Category 从“卡片上的一个标签”变成“列表结构骨架”
2. Label 从“分类信息”彻底回到“补充属性”

---

# 1. 当前项目已经具备什么基础

你现在的项目并不是空白状态，而是已经具备了能支撑这次改造的底层基础。

## 1.1 已经存在的基础设施

### 数据模型

当前 `TodoItem` 已经具备：

- `priority`
- `dueAt`
- `remindAt`
- `repeatType`
- `repeatRule`
- `categoryId`
- `pinned`
- `completedAt`
- `deletedAt`
- `orderIndex`
- `confidence`
- `meta`

### 数据库

SQLite 已经有：

- `todo_item`
- `categories`
- `tags`
- `todo_tags`
- `reminders`

### 查询与排序

你已经有：

- `TodoSortField`
- `SortDirection`
- `TodoQueryOptions`
- `TodoQueryBuilder`
- `TodoRepository.getTodos(...)`

### 分类/标签

你已经有：

- `CategoryRepository`
- `TagRepository`
- 分类选择页
- 标签选择页
- 分类创建页
- 标签创建页

### 设置与状态

你已经有：

- `SettingsState`
- `SettingsRepository`
- `SettingsNotifier`
- `TodoListNotifier`
- `app_providers`

### 首页和卡片

已经有：

- 首页待办列表
- 批量选择模式
- 录音遮罩
- 悬浮录音按钮
- 待办卡片组件 `TodoItemCard`

---

# 2. 这次改造的目标状态是什么

改造完成后，用户看到的首页应该是这样的结构：

```text
[工作组]
  Todo 1
  Todo 2
  Todo 3

[生活组]
  Todo 1
  Todo 2

[健康组]
  Todo 1

[未分类组]
  Todo 1
  Todo 2
```

每个组有：

- 左侧连续色带
- 组壳
- 组头标题
- 展开/收起小三角
- 组内虚线分隔
- 组拖拽把手

每条 Todo 内有：

- 完成圆圈
- 主标题
- 时间 / 优先级
- Label chips
- 编辑 / 删除 / 重录 / 设置提醒入口

---

# 3. 这次改造的设计原则

## 3.1 Category 变成“分组骨架”

Category 的职责不再是“给每条卡片贴标签”，而是：

- 决定一组 Todo 的归属
- 决定组的边界
- 决定组壳的视觉表达
- 决定列表的层级结构

### 设计上要记住

- Category 不是 chip
- Category 不是普通 tag
- Category 是“组头”

---

## 3.2 Label 变成“辅助属性”

Label 仍然属于每条 Todo 自己：

- 可多个
- 轻量显示
- 不参与组壳结构
- 不承担列表组织责任

### 设计上要记住

- Label 不是分组
- Label 是“这件事的附加说明”

---

## 3.3 排序变成两层

### 第一层：组顺序

组顺序由用户拖拽决定。

### 第二层：组内 Todo 顺序

组内 Todo 由排序规则决定：

- 手动
- 创建时间
- 截止时间
- 优先级

### 重点

**不再保留“按 Category 排序”作为用户可见的全局排序项。**

因为 Category 本身已经成为分组结构，不再是排序维度。

---

# 4. 新的总架构应该怎么理解

你可以把新的结构想成三层：

```text
UI 层
  ↓
Grouping 层（把 Todo 分成组）
  ↓
Repository / SQLite 层（拿原始 Todo）
```

## 4.1 Repository 的职责

Repository 只负责：

- 查询 Todo
- 更新 Todo
- 保存 Todo
- 删除 Todo
- 修改 priority / dueAt / category / tags / reminder

不要让 Repository 直接关心 UI 怎么分组。

---

## 4.2 Grouping 层的职责

新增一个“分组构建层”，负责：

- 把扁平 Todo 列表转换成按 Category 分组的数据结构
- 给没有 Category 的 Todo 自动归入“未分类”组
- 对每个组内部的 Todo 做排序
- 输出给 UI 直接渲染

---

## 4.3 UI 层的职责

UI 只负责：

- 画出组壳
- 画出组头
- 画出组内 Todo
- 处理折叠、拖拽、点击、编辑

UI 不应该自己去拼分组逻辑。

---

# 5. 推荐的数据结构改造

## 5.1 新增 `TodoGroup`

建议新增一个分组模型，而不要让 UI 自己拿列表拼。

### 文件建议

- `lib/models/todo_group.dart`

### 推荐字段

```dart
class TodoGroup {
  final String groupKey;          // categoryId 或 'uncategorized'
  final String title;             // 组显示名称
  final String? categoryId;       // 真正的分类 ID，没有则为 null
  final List<TodoItem> items;     // 组内 Todo
  final bool isExpanded;          // 是否展开
  final int groupOrderIndex;      // 组顺序

  const TodoGroup({
    required this.groupKey,
    required this.title,
    required this.items,
    required this.isExpanded,
    required this.groupOrderIndex,
    this.categoryId,
  });
}
```

---

## 5.2 未分类组的约定

统一把没有 `categoryId` 的 Todo 放入：

- `groupKey = 'uncategorized'`
- `title = '未分类'`
- `categoryId = null`

这样后面无论是 UI 还是业务逻辑，都能稳定识别。

---

## 5.3 是否需要为组单独建表

### MVP 方案

先不建新表，组顺序可以先存在：

- SharedPreferences

### 稳定方案

如果后面组顺序会长期保存，建议新增一个表：

- `category_order`
  - `category_id`
  - `sort_order`

### 建议

如果你现在已经有较完整的 SQLite 迁移能力，**可以直接做 SQLite 版组顺序保存**，这样后面更稳。

---

# 6. 查询层要怎么改

## 6.1 现在查询的角色不变

你已经有：

- `TodoQueryOptions`
- `TodoQueryBuilder`
- `TodoRepository.getTodos(...)`

这些基础设施继续保留。

---

## 6.2 需要改变的是“最终用途”

现在查询出来的结果不再直接喂给 UI 渲染成卡片列表，而是：

1. 先查询出一批 Todo
2. 再按 Category 分组
3. 再给每组内部排序
4. 最后交给 UI 渲染组结构

---

## 6.3 删除“按 Category 排序”作为用户排序选项

### 之前

`TodoSortField.category`

### 现在

建议从用户可见排序项中移除。

### 原因

因为 Category 已经承担了“分组骨架”的职责，不应该再作为普通排序字段出现。

---

## 6.4 保留的排序项

保留这些组内排序项：

- `manual`
- `createdAt`
- `dueAt`
- `priority`

### 含义

- `manual`：组内手动顺序
- `createdAt`：组内按创建时间
- `dueAt`：组内按截止时间
- `priority`：组内按优先级

---

# 7. 新增分组服务

## 7.1 为什么必须新增

因为现在 UI 不能再直接消费 `List<TodoItem>`。

你需要一个中间层把它变成 `List<TodoGroup>`。

---

## 7.2 新文件建议

- `lib/services/todo_grouping_service.dart`

---

## 7.3 它的职责

### 输入

- Todo 列表
- 分类列表
- 当前排序规则
- 当前排序方向
- 当前组顺序

### 输出

- 按 Category 分组后的 `List<TodoGroup>`

---

## 7.4 分组流程建议

```dart
List<TodoGroup> buildGroups(
  List<TodoItem> todos,
  List<Category> categories,
  TodoSortField sortField,
  SortDirection direction,
  Map<String, int> groupOrderMap,
) {
  final Map<String, List<TodoItem>> bucket = {};

  for (final todo in todos) {
    final key = todo.categoryId ?? 'uncategorized';
    bucket.putIfAbsent(key, () => []);
    bucket[key]!.add(todo);
  }

  final groups = bucket.entries.map((entry) {
    final isUncategorized = entry.key == 'uncategorized';
    final categoryId = isUncategorized ? null : entry.key;

    final title = isUncategorized
        ? '未分类'
        : categories.firstWhere((c) => c.id == categoryId).name;

    final sortedItems = sortTodosWithinGroup(entry.value, sortField, direction);

    return TodoGroup(
      groupKey: entry.key,
      title: title,
      categoryId: categoryId,
      items: sortedItems,
      isExpanded: true,
      groupOrderIndex: groupOrderMap[entry.key] ?? 0,
    );
  }).toList();

  groups.sort((a, b) => a.groupOrderIndex.compareTo(b.groupOrderIndex));

  return groups;
}
```

---

# 8. 组顺序拖拽怎么做

## 8.1 拖拽的是“组头”

你要求的是：

- 组本身可拖拽
- 用户按住组头的拖拽区域即可移动整个组

### 推荐拖拽区域

组头右侧：

- 拖拽图标
- 三横线
- 点阵把手

不要让整组都可拖拽，否则容易误触。

---

## 8.2 组拖拽的结果

拖完之后：

- 更新组顺序
- 持久化组顺序
- 刷新列表

### 注意

拖拽组时不应改动组内 Todo 的顺序。

---

## 8.3 组顺序存储方案

### 推荐做法

新增一个持久化表或持久化映射：

```text
category_order
- category_id
- sort_order
```

### 未分类组

可用固定 key：

- `uncategorized`

### 组顺序默认值

- 如果用户没拖过，按分类创建时间或当前展示顺序初始化
- 未分类组建议放末尾

---

# 9. 组内 Todo 排序怎么做

## 9.1 组内排序规则

组内排序继续沿用现有能力：

- 手动
- 创建时间
- 截止时间
- 优先级

### 重点

这些排序只影响**组内**，不影响组与组之间的顺序。

---

## 9.2 手动排序模式下的组内拖拽

当排序字段是 `manual` 时：

- 组内 Todo 可拖拽
- 拖拽后保存 `orderIndex`
- 只更新当前组内部的顺序

---

## 9.3 非手动排序模式

当排序字段不是 `manual` 时：

- 禁用组内拖拽
- 仅按当前排序规则展示

### 建议

通过 UI 明确提示：

- 当前排序模式下不支持手动调整顺序

---

# 10. UI 大改造：如何把布局转成 Flutter 代码

这一部分是最关键的落地指导。

---

## 10.1 首页渲染总结构

推荐把首页从平铺列表改成：

```text
HomeScreen
 ├─ 顶部工具区
 ├─ 排序 / 筛选入口
 ├─ 分组列表区域
 │   ├─ TodoGroupSection
 │   ├─ TodoGroupSection
 │   └─ TodoGroupSection
 └─ 底部录音按钮 / 工具条
```

---

## 10.2 新增组件拆分建议

### 1）`TodoGroupSection`

负责渲染整个组。

#### 输入

- `TodoGroup group`
- `VoidCallback onToggleExpanded`
- `VoidCallback onDragStart`
- `void Function(int from, int to)` onReorderWithinGroup

#### 作用

- 显示组壳
- 显示左侧色带
- 显示组头
- 展开 / 收起组内容
- 显示组内 todo

---

### 2）`TodoGroupHeader`

负责显示组头。

#### 显示内容

- Category 名称
- Todo 数量
- 折叠小三角
- 拖拽把手

#### 视觉原则

- Category 是标题，不是 chip
- 分类名称要比普通 Label 更稳、更结构化

---

### 3）`TodoGroupBody`

负责显示组内 todo。

#### 规则

- 每条 todo 之间用虚线分隔
- 组内列表有统一 padding
- 组头和第一条 todo 之间留空间

---

### 4）`TodoRowTile`

负责显示组内的一条 todo。

#### 保留的内容

- 完成圆圈
- 主标题
- 时间
- 优先级
- Label chips
- 操作按钮

#### 去掉的内容

- 重复显示的 Category chip

因为 Category 已经在组头上显示过了。

---

## 10.3 推荐的组壳外观

每个组建议有一个外壳 Container：

- 圆角 20 左右
- 轻微阴影
- 淡背景
- 左侧有连续色带
- 内部白底或极浅背景

### 左侧色带

- 宽度不宜过大
- 颜色要浅
- 不要抢正文

### 组头

- 放在组壳顶部
- 显示一次分类名
- 显示总条数
- 右边放折叠小三角

---

## 10.4 虚线分隔线

组内 Todo 之间不要用实线边框，改成：

- 浅灰虚线
- 细线宽度
- 低存在感

这样可以让列表更统一，也更高级。

---

## 10.5 Label 的显示位置

Label 应该仍然每条 Todo 显示，但位置要轻量化。

### 推荐位置

- 主标题下方
- 时间 / 优先级附近
- 作为底部补充行

### 样式

- 小 chip
- 轻背景
- 可折叠成 `+N`

### 目的

让 Label 看起来是“附加说明”，而不是“第二层分类”。

---

# 11. 如何尽量利用你现有的代码基础设施

这次大改最好不要新开一套完全独立的体系，而是利用现有东西继续往上叠。

## 11.1 保留并继续使用的基础设施

### 数据层

- `TodoItem`
- `TodoRepository`
- `DatabaseHelper`
- `CategoryRepository`
- `TagRepository`
- `ReminderRepository`

### 状态层

- `TodoListNotifier`
- `SettingsNotifier`
- `app_providers`

### 设置层

- 主题
- 字号
- 默认优先级
- 排序偏好

### 通知层

- `NotificationService`
- `ReminderService`

---

## 11.2 只新增必要的中间层

建议新增：

- `TodoGroup`
- `todo_grouping_service.dart`

不要一下子重构成太多新体系。

---

## 11.3 现有 Repository 的改造方向

`TodoRepository` 不要负责 UI 分组，只负责返回原始数据。

`TodoListNotifier` 可以从 Repository 拿到 todo 列表，再交给 grouping service。

这能最大程度保留你现有的架构。

---

# 12. 设置和排序逻辑要怎么改

## 12.1 删掉“按 Category 排序”这一项

排序设置里不再出现：

- 按分类排序

因为分类现在不是排序维度，而是分组维度。

---

## 12.2 只保留组内排序项

保留：

- 手动顺序
- 创建时间
- 截止时间
- 优先级

---

## 12.3 设置项的作用范围

- 排序字段：只影响组内 Todo
- 排序方向：只影响组内 Todo
- 组顺序：由拖拽单独控制

这三者要明确分开，不要混在一起。

---

# 13. 组折叠的实现建议

## 13.1 折叠状态存储

建议每个组保存一个展开状态：

- `Map<String, bool>`

可以先存在 `TodoListNotifier` 的 state 里，后续再持久化。

---

## 13.2 折叠交互

组头点击：

- 展开 / 收起组内容

### 动画

- 用 `AnimatedSize`
- 或 `AnimatedCrossFade`

这样不会显得生硬。

---

# 14. 开发顺序建议

为了避免一次改太大，建议按下面顺序推进。

## 第 1 步：先做分组数据

- 新增 `TodoGroup`
- 新增 grouping service
- 从现有 `TodoItem` 列表构建 groups

## 第 2 步：改首页主结构

- 首页从平铺列表改成 group list
- 先能显示组壳和组头

## 第 3 步：改组内 todo 样式

- 去掉重复 category chip
- 加虚线分隔
- Label 保持轻量 chip

## 第 4 步：加折叠

- 组头小三角
- 展开 / 收起组内容

## 第 5 步：加组拖拽

- 组头拖拽把手
- 保存组顺序

## 第 6 步：加组内拖拽

- 仅 manual 模式可用
- 保存组内顺序

## 第 7 步：清理旧排序逻辑

- 删除按 Category 排序入口
- 收敛旧平铺逻辑
- 简化不必要的刷新

---

# 15. 迁移和兼容策略

## 15.1 旧数据兼容

必须保证：

- 没有分类的旧 Todo 自动进入“未分类”组
- 旧数据的 `orderIndex` 不丢
- 旧数据的 `priority` / `dueAt` / `remindAt` / `tags` 正常显示

---

## 15.2 旧页面兼容

如果暂时不想完全删除原平铺式显示，可以先做一个开发开关或隐藏视图模式。

### 但是建议

正式版默认使用分组视图。

---

# 16. 验收标准

## 数据层

- 所有 Todo 都能正确归组
- 没有 Category 的 Todo 都进入“未分类”组
- 组内 Todo 顺序稳定

## UI 层

- 组壳明确可见
- 左侧色带统一出现
- 组头有折叠三角
- 组内有虚线分隔
- Label 每条都能显示，但不会显得像第二个分类

## 交互层

- 组可拖拽
- 组内 Todo 在 manual 模式下可拖拽
- 非 manual 模式下禁用拖拽
- 展开 / 收起流畅

## 排序层

- 不再存在“按 Category 排序”的用户入口
- 组内排序只作用于组内
- 组顺序和组内顺序分开管理

---

# 17. 给新接手开发者的执行口令

> 当前项目已经完成语音录入、SQLite 持久化、优先级、提醒、截止时间、分类、标签、排序等基础能力。下一步要把列表从平铺式改成 Category 分组视图：Category 作为组壳和结构骨架，未分类 Todo 自动进入“未分类”组，组内 Todo 用虚线分隔，Label 以轻量 chip 每条显示，组头要有折叠三角和拖拽把手。排序规则要调整为“组内排序 + 组顺序拖拽”，去掉“按 Category 排序”的全局模式。实现时请尽量复用现有的 TodoRepository、TodoQueryOptions、Settings、Provider、Category/Tag Repository 和 TodoItem 数据模型，只新增分组构建层与必要的 UI 组件，不要重做整套架构。

---

# 18. 最后一句总结

这次改造的本质是：

- **Category 从属性变成结构**
- **Label 保持属性角色**
- **列表从平铺变成分组**
- **排序从全局变成组内**
- **拖拽从单条变成组与组内两层**
- **UI 从普通卡片升级成组壳式列表**

