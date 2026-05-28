下面这份是按你**当前代码状态**整理的“究极清单”。我先给结论：**你现在最该做的，不是继续加新功能，而是把已经建好的后端能力真正接到 UI 和状态层上。**

---

# 语音待办项目下一步究极清单

## 0. 你当前已经做到哪一步了

我看了你最新代码，当前已经具备这些基础：

* `TodoItem` 已经有了优先级、截止时间、提醒时间、分类、完成时间等字段
* SQLite 已经有：

  * `categories`
  * `tags`
  * `todo_tags`
  * `reminders`
* 已经有：

  * `TodoPriority`
  * `TodoSortField`
  * `SortDirection`
  * `TodoQueryOptions`
  * `TodoQueryBuilder`
* `TodoRepository` 已经有统一查询入口 `getTodos(TodoQueryOptions options)`
* `ReminderService` 已经存在
* `CategoryRepository`、`TagRepository` 已经存在
* 首页已经有排序入口的骨架
* 待办卡片里已经能取分类名、优先级标签、提醒时间

所以现在的状态不是“还没开始”，而是：

> **后端骨架已搭完，前端和状态层还没完全接上。**

---

# 1. 当前最高优先级：先把排序系统做完整

这是你现在最该做的一件事。

## 1.1 目标

用户能在 App 里真正切换：

* 按手动顺序
* 按创建时间
* 按截止时间
* 按优先级
* 按分类

并且能选择：

* 升序
* 降序

---

## 1.2 需要改的文件

* `lib/screens/home_screen.dart`
* `lib/models/settings_state.dart`
* `lib/providers/settings_provider.dart`
* `lib/repositories/settings_repository.dart`
* `lib/providers/app_providers.dart`
* `lib/data/todo_repository.dart`

---

## 1.3 具体要做什么

### A. 把首页的“排序功能开发中”换成真面板

你现在 `home_screen.dart` 里排序入口还是占位文案。
这一步要改成一个真正的 BottomSheet。

面板里放：

* 单选排序字段
* 单选升序 / 降序
* 一个“应用”按钮

建议排序项：

* 手动顺序
* 创建时间
* 截止时间
* 优先级
* 分类

---

### B. 把排序偏好写进 Settings

你现在 `SettingsState` 里还没有看到排序偏好的持久化字段。
要补上：

* `todoSortField`
* `todoSortDirection`

并在 SharedPreferences 里保存：

* `todo_sort_field`
* `todo_sort_direction`

---

### C. 排序切换后要立刻刷新列表

`TodoListNotifier` 不要只靠 `loadTodos()` 默认顺序。
要改成：

* 从 `SettingsState` 读取排序偏好
* 组装成 `TodoQueryOptions`
* 调用 `getTodos(options)`

---

## 1.4 这一块的验收标准

* 用户能从首页切换排序
* 退出 App 再打开，排序方式还在
* 排序切换后列表立即变化
* 不影响录音新增待办流程

---

# 2. 立刻修一个会影响后续状态切换的 bug

## 2.1 文件

* `lib/models/todo_query_options.dart`

## 2.2 问题

你现在 `copyWith()` 里这类写法需要修正：

```dart
categoryId: categoryId,
```

这会让原值丢失。

## 2.3 应该改成

```dart
categoryId: categoryId ?? this.categoryId,
```

## 2.4 为什么现在必须修

因为后面你会频繁做：

* 切排序
* 切筛选
* 切分类
* 保留原查询条件

这个 bug 不修，查询状态很容易被覆盖。

---

# 3. 把优先级真正接到 UI

你现在优先级已经进数据库了，但用户还不够“看得见、改得动”。

## 3.1 需要改的文件

* `lib/widgets/todo_item_card.dart`
* `lib/providers/app_providers.dart`
* `lib/data/todo_repository.dart`
* 未来可能还要改一个编辑弹窗或详情页

---

## 3.2 现在的问题

我看到 `TodoItemCard` 里已经预留了：

* `priorityLabel`
* `categoryName`

但优先级的展示/编辑还不完整，或者入口不够直接。

---

## 3.3 具体要做什么

### A. 卡片上显示优先级

建议展示为小 Chip 或很轻的标签：

* 低
* 普通
* 高
* 紧急

不要做大块颜色，保持极简。

### B. 提供修改优先级的入口

建议放在长按菜单或编辑底部菜单里。

菜单项建议包括：

* 设置提醒
* 设置截止时间
* 设置分类
* 设置优先级
* 删除

### C. 状态层加优先级更新方法

确保 `TodoListNotifier` 有这种能力：

* `updatePriority(String id, TodoPriority priority)`

---

## 3.4 验收标准

* 每条待办都能看到当前优先级
* 用户能修改优先级
* 改完后卡片即时更新
* 排序选“按优先级”时结果正确

---

# 4. 把标签功能做成“可用”，不是“只存库”

## 4.1 现状

你已经有：

* `tags` 表
* `todo_tags` 表
* `TagRepository`

但前端还不完整。

---

## 4.2 需要改的文件

* `lib/providers/app_providers.dart`
* `lib/widgets/todo_item_card.dart`
* 新增一个 tag 选择页或弹窗
* 可能补 `lib/screens/tag_manage_screen.dart`

---

## 4.3 现在要做什么

### A. 做一个最小闭环的标签入口

建议在待办编辑菜单里加：

* 添加标签
* 管理标签
* 清除标签

### B. 首页卡片只展示少量标签

最多展示 1～2 个，不要堆太多。

### C. 做一个 `tagListProvider`

你现在有 `categoryListProvider`，但标签这边还需要同类的 provider。

---

## 4.4 验收标准

* 能给待办加标签
* 能删除标签
* 卡片上能看到标签
* 标签不会影响语音录入主流程

---

# 5. 把提醒系统做成闭环

## 5.1 现状

你已经有：

* `NotificationService`
* `ReminderService`
* `remindAt`
* `reminders` 表

这很好，但现在还要保证修改链路完整。

---

## 5.2 需要改的文件

* `lib/services/reminder_service.dart`
* `lib/data/reminder_repository.dart`
* `lib/widgets/todo_item_card.dart`
* `lib/providers/app_providers.dart`
* `lib/data/todo_repository.dart`

---

## 5.3 具体要做什么

### A. 修改提醒后，统一同步调度

流程应该是：

1. 更新数据库里的 `remindAt`
2. 重新读取最新 todo
3. 调 `scheduleReminderForTodo(updatedTodo)`
4. 刷新列表状态

### B. 清除提醒后，要同时清掉三样东西

* `todo_item.remindAt = null`
* 删除 `reminders` 记录
* 取消本地通知

### C. 删除待办时也要清理提醒

这部分你基本有了，但还要确认：

* 通知取消
* reminder 记录删除
* 以后如果加重复规则，也要一起删

---

## 5.4 验收标准

* 设置提醒后，通知能准时触发
* 修改提醒后，旧通知不会残留
* 删除提醒后，通知消失
* 删除待办后，相关提醒彻底清掉

---

# 6. 再做分类功能的“真正查询”

## 6.1 现状

你已经有 `CategoryRepository` 和 `categoryId`，但排序上还只是字符串级别。

我看到你现在的分类排序逻辑还偏基础，后面如果要做“分类升降序”，不能只按 `category_id` 字符串排。

---

## 6.2 需要改的文件

* `lib/data/todo_query_builder.dart`
* `lib/data/database_helper.dart`
* `lib/data/category_repository.dart`
* 未来可能新增分类筛选 UI

---

## 6.3 推荐方向

以后真正要做分类排序，应该走：

* `todos.category_id`
* `categories.id`
* `categories.sort_order`
* `categories.name`

然后查询时用 `LEFT JOIN categories`。

---

## 6.4 现在可以先做什么

先做最小版：

* 分类选择
* 分类显示
* 分类筛选

等 UI 闭环后，再把 join 排序补上。

---

# 7. 现在别急着做的东西

以下内容可以暂缓，不要抢先做：

* 复杂自然语言时间解析
* 多提醒规则
* 复杂重复规则
* 排序动画的精细打磨
* 云同步
* 多设备迁移
* 全局搜索
* 统计分析页

原因很简单：

> 你的核心数据流已经开始成型，现在最重要的是“查询、状态、显示、修改”四条线完整打通。

---

# 8. 文件级执行清单

下面这份可以直接照着排期。

---

## 第 1 组：必须先做

### `lib/screens/home_screen.dart`

* 把“排序功能开发中”改成真正的排序 BottomSheet
* 让用户能选排序字段和升降序
* 排序后立即刷新列表

### `lib/models/settings_state.dart`

* 增加 `todoSortField`
* 增加 `todoSortDirection`

### `lib/providers/settings_provider.dart`

* 增加读取和写入排序偏好的方法

### `lib/repositories/settings_repository.dart`

* 加 SharedPreferences 存取键
* 启动时读取排序偏好

### `lib/models/todo_query_options.dart`

* 修正 `copyWith()`
* 保证字段不会被误覆盖

---

## 第 2 组：优先级接 UI

### `lib/widgets/todo_item_card.dart`

* 显示优先级
* 显示分类
* 显示提醒时间
* 给长按菜单加“修改优先级”

### `lib/providers/app_providers.dart`

* 增加 `updatePriority`
* 统一刷新逻辑

### `lib/data/todo_repository.dart`

* 确保优先级更新方法可直接调用
* 如有需要，补一个“查询后局部更新”的 helper

---

## 第 3 组：标签闭环

### `lib/providers/app_providers.dart`

* 增加标签列表 provider
* 增加标签编辑入口状态

### 新增/补充标签管理页面

* 新建标签
* 删除标签
* 给待办打标签
* 展示标签列表

---

## 第 4 组：提醒闭环

### `lib/services/reminder_service.dart`

* 检查修改提醒、清除提醒、重建提醒的同步逻辑
* 确保通知与数据库一致

### `lib/data/reminder_repository.dart`

* 确保 `upsert / delete / mark fired` 正常

---

## 第 5 组：分类进阶

### `lib/data/todo_query_builder.dart`

* 未来改为 join categories
* 支持分类名 / 分类顺序排序

### `lib/data/database_helper.dart`

* 保持分类表结构稳定
* 为后续筛选做好索引和约束

---

# 9. 给刚接手这个项目的 AI 的执行口令

你可以把下面这段直接给后续 AI：

> 当前项目已经完成 Flutter + Vosk + SQLite 的语音待办基础闭环，并且加入了优先级、提醒、分类、标签、统一排序枚举和查询选项对象。下一步请优先把排序 UI、优先级 UI、标签闭环、提醒联动做完整，不要先做动画或复杂自然语言解析。开发时注意：排序偏好要持久化到 Settings，列表查询要统一走 TodoQueryOptions，状态更新尽量避免整页重载，保证语音录入主流程不受影响。

---

# 10. 最后的执行顺序建议

如果你现在就开工，推荐顺序是：

1. 修 `TodoQueryOptions.copyWith`
2. 做排序 BottomSheet
3. 把排序偏好写进 Settings
4. 在卡片上显示优先级
5. 增加优先级修改入口
6. 做标签最小闭环
7. 收紧提醒同步逻辑
8. 再做分类 join 排序

---

# 11. 一句话版总结

你现在最该做的，是把这四件事打通：

* **排序能用**
* **优先级能看能改**
* **标签能加能删**
* **提醒能改能清**

只要这四条线完整，项目就从“有后端骨架”变成“真正可用的增强版待办 App”。
