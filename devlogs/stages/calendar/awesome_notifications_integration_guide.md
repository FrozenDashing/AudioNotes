# 在当前 Flutter Todo 项目中接入 `awesome_notifications` 的实现指南

> 目标：让 Todo 的提醒在 **应用关闭后仍然能够按时弹出**，并且尽量少改现有架构。  
> 适用对象：刚接手这个项目的 AI 或开发者。  
> 结论先说：**保留现有 `ReminderService` 作为业务入口，只把底层通知实现替换成 `awesome_notifications`**。

---

## 1. 这个需求到底要解决什么

当前项目里，提醒主要依赖本地通知服务，但接手者希望实现：

- App 关闭后，到了提醒时间仍然能弹通知
- 行为尽量像 WhatsApp 一样：用户不需要打开 App，也能收到提醒
- 不破坏现有 Todo 的创建、编辑、删除、恢复、同步逻辑
- 后续还能继续支持：
  - 本地通知
  - 系统日历同步
  - 垃圾桶软删除与恢复
  - WebDAV / 云端同步

这个需求本质上是：**把“通知调度”交给系统，而不是依赖 App 常驻运行**。

`awesome_notifications` 正适合做这一层。

---

## 2. 为什么选 `awesome_notifications`

它适合当前项目的原因：

1. **支持定时通知**  
   可以在指定时间触发通知，App 关闭后仍可由系统显示。

2. **保留原生通知能力**  
   Android / iOS 都能走原生通知体系，不需要自己写后台轮询。

3. **适合“提醒”类业务**  
   Todo、日程、闹钟、待办提醒都属于它的强项。

4. **可以承载后续扩展**  
   后面如果要做：
   - 通知点击跳转到某个 Todo
   - 通知动作按钮
   - 分组通知
   - 通知取消、更新、重建
   都比较顺。

---

## 3. 在这个项目里，建议保留的架构

不要把所有提醒逻辑直接写进 UI，也不要让页面直接调用插件。

推荐保持这个层次：

```text
TodoPage / SettingsPage
        ↓
TodoNotifier / SettingsNotifier
        ↓
ReminderService
        ↓
AwesomeNotificationService
        ↓
awesome_notifications 插件
```

### 各层职责

#### UI 层
只负责展示、交互、收集用户输入。

#### Notifier / Controller 层
只负责把用户操作转换成业务动作。

#### `ReminderService`
作为提醒业务入口：
- 新建提醒
- 更新提醒
- 取消提醒
- 恢复后重建提醒

#### `AwesomeNotificationService`
只负责和插件交互：
- 初始化
- 请求权限
- 创建通知
- 更新通知
- 取消通知
- 处理点击回调

---

## 4. 应该修改哪些文件

建议最少动这些文件：

- `lib/main.dart`
- `lib/services/reminder_service.dart`
- 新增 `lib/services/awesome_notification_service.dart`
- `lib/services/notification_controller.dart`（处理点击和后台回调）
- `lib/models` 里和通知有关的数据结构（如有）
- `lib/repositories/settings_repository.dart`（如果要保留本地通知 / 系统日历 / 日历同步开关）
- `lib/providers` 或 `lib/notifiers` 中触发提醒的地方

### 不建议直接大改的文件

- Todo 主列表的 UI 组件
- 任务编辑页的布局
- WebDAV 同步主流程
- 数据库结构中与提醒无关的字段

原则：**先把提醒链路单独抽出来，再接回业务流**。

---

## 5. 初始化应该放哪里

`awesome_notifications` 需要在 `main.dart` 里初始化。

### 关键原则

- `initialize()` 只调用一次
- 在 `runApp()` 之前完成
- `setListeners()` 也在启动阶段设置好

### 初始化职责

- 定义通知频道
- 绑定点击回调
- 绑定展示、创建、关闭等回调
- 确保应用被杀掉后，系统依然能按计划显示通知

---

## 6. 推荐的文件结构

```text
lib/
  services/
    reminder_service.dart
    awesome_notification_service.dart
    notification_controller.dart
  notifiers/
    todo_list_notifier.dart
    settings_notifier.dart
  repositories/
    settings_repository.dart
  main.dart
```

---

## 7. `AwesomeNotificationService` 的职责

这个类是底层实现层，不参与业务判断。

它只做以下事情：

- 初始化通知插件
- 检查通知权限
- 请求通知权限
- 创建一个提醒通知
- 更新一个提醒通知
- 取消一个提醒通知
- 接收点击事件并转发

### 这个层里不要做的事

不要：

- 判断 Todo 是否已完成
- 判断是否是软删除
- 判断是不是垃圾桶里的数据
- 读取数据库里复杂的业务状态

这些事情应该在 `ReminderService` 或上层 notifier 中做。

---

## 8. `ReminderService` 的职责

这是项目里最重要的中间层。

### 它应该知道

- 某个 Todo 是否需要提醒
- 提醒时间是什么
- Todo 是否被删除
- Todo 是否被恢复
- 当前通知模式是什么

### 它应该提供的方法

```dart
scheduleReminderForTodo(todo)
updateReminderForTodo(todo)
cancelReminderForTodo(todoId)
restoreReminderForTodo(todo)
```

### 它不应该直接依赖 UI

不要让页面直接调用 `awesome_notifications`。
页面只要调用 notifier，notifier 再调 `ReminderService`。

---

## 9. 通知 ID 的设计

非常关键。

每个 Todo 必须有一个**稳定的通知 ID**。

### 为什么需要稳定 ID

因为：

- 更新通知时要覆盖旧通知
- 删除 Todo 时要取消对应通知
- 恢复 Todo 时要重新创建
- 不能每次都生成随机 ID，否则更新和取消会失效

### 推荐做法

用 Todo 的唯一 ID 计算出通知 ID：

- 数据库主键 `todo.id`
- 或者 `todo.uuid`
- 再映射成 `int`

要确保：

- 同一个 Todo 每次得到的通知 ID 都一致
- 不同 Todo 之间不要撞 ID

---

## 10. 通知内容怎么组装

建议通知内容尽量简单明确。

### 标题
Todo 标题。

### 正文
可以显示：

- 任务描述
- 距离截止时间还有多久
- 任务的优先级
- 任务所属分类

### 建议格式

```text
标题：准备周会材料
正文：今天 18:00 前需要完成
```

不要把正文写得太长，否则在通知栏里会显示不完整。

---

## 11. 通知调度的基本规则

### 新建 Todo
如果用户设置了提醒时间：
- 立即调度通知

### 编辑 Todo
如果标题、提醒时间、截止时间变化：
- 先取消旧通知
- 再创建新通知

### 软删除 Todo
- 立即取消通知
- 不要让垃圾桶里的 Todo 继续弹提醒

### 恢复 Todo
- 检查提醒时间是否还有效
- 如果有效，重新创建通知

### 永久删除 Todo
- 取消通知
- 之后再清数据库、音频文件、同步记录

---

## 12. 设置里应该保留什么

如果项目里已经有“通知模式”设置，就建议保留。

例如：

- `local`：本地提醒（`awesome_notifications`）
- `calendar`：系统日历同步
- 未来可扩展：云通知、系统级闹钟等

### 当前目标

本次目标是把 `local` 的实现换成 `awesome_notifications`，确保：

- App 关闭后仍能提醒
- 不影响现有设置页结构
- 不影响 Todo 生命周期

---

## 13. 通知权限处理

必须在用户真正启用提醒前检查权限。

### 推荐流程

1. 先调用 `isNotificationAllowed()` 或等价检查
2. 如果没有权限，再请求权限
3. 权限被拒绝时，提示用户去系统设置打开

### 需要注意

- iOS 需要用户明确授权
- Android 13+ 也需要通知权限
- Android 12 及以下一般不需要新增运行时通知权限，但定时精确通知可能还有系统限制

---

## 14. App 关闭后为什么还能提醒

这个是 AI 接手时最容易误解的点。

### 不是因为 App 在后台一直跑

不是。

### 而是因为系统已经接管了通知调度

当你用 `awesome_notifications` 提前把通知注册到系统里后：

- 系统会在指定时间显示通知
- Dart 代码不需要一直运行
- App 被关闭也不影响通知出现

这就是它适合 Reminder / Todo 的原因。

---

## 15. 回调处理应该怎么做

需要一个专门的通知控制器。

### 常见回调

- 通知被点击
- 通知被创建
- 通知被展示
- 通知被关闭

### 推荐用途

#### 点击通知
读取 payload 里的 `todoId`，跳转到对应详情页。

#### 通知创建/展示
只做日志或埋点。

#### 通知关闭
一般不需要复杂逻辑。

---

## 16. 和现有 Todo 数据的映射关系

建议数据库里至少保留这些概念：

- `todo.id`
- `todo.remindAt`
- `todo.dueAt`
- `todo.deletedAt`
- `todo.notificationId`
- `todo.notificationMode`

### 为什么要保存 `notificationId`

这样恢复、取消、更新都能直接定位对应通知。

---

## 17. 和软删除 / 垃圾桶的关系

这个项目里已有软删除和垃圾桶设想，所以要明确：

### 软删除时
- 取消通知
- 不再让它弹提醒

### 恢复时
- 如果提醒时间还有效，重新调度

### 永久删除时
- 删除通知记录
- 删除数据库记录
- 删除关联资源

### 自动清理垃圾桶时
- 先取消通知（如果还有残留）
- 再永久删除

---

## 18. 和系统日历同步的关系

如果未来同时保留系统日历功能，那么提醒来源会有两种：

1. `awesome_notifications`：应用自己的本地提醒
2. `device_calendar_plus`：写入系统日历

### 推荐策略

先明确用户选择哪一种：

- 选择本地提醒：走 `awesome_notifications`
- 选择系统日历：走日历插件

不要让两个系统同时抢同一条提醒，容易重复弹出。

---

## 19. 推荐的实现顺序

### 第一步
新增 `AwesomeNotificationService`。

### 第二步
在 `main.dart` 完成初始化和回调注册。

### 第三步
把 `ReminderService` 改成业务调度入口。

### 第四步
把 Todo 创建、编辑、删除、恢复流程接入新的通知服务。

### 第五步
补上权限申请和通知点击跳转。

### 第六步
测试以下场景：
- App 打开时提醒
- App 切后台时提醒
- App 完全关闭后提醒
- 删除 Todo 后不再提醒
- 恢复 Todo 后重新提醒
- 修改提醒时间后旧通知被正确替换

---

## 20. 最容易出错的地方

1. **通知 ID 不稳定**  
   会导致取消失败、重复提醒。

2. **没有在 `main.dart` 初始化**  
   通知不会正确注册。

3. **把通知逻辑写进 UI**  
   会让后期维护很痛苦。

4. **删除 Todo 时只删数据库，不取消通知**  
   会出现幽灵通知。

5. **恢复 Todo 后没重新调度**  
   会导致恢复后没有提醒。

6. **同一个 Todo 被重复创建多次通知**  
   更新时必须先取消旧的。

---

## 21. 给接手 AI 的实现原则

- 保持现有业务层不变
- 只替换提醒底层实现
- 用稳定 ID 管理每条通知
- Todo 的增删改恢复都必须同步处理通知
- 不要把权限申请、创建通知、删除通知散落在多个 UI 文件里
- 不要用随机 ID 代替数据库主键映射

---

## 22. 一句话总结

`awesome_notifications` 在这个项目里的作用，是把“提醒”从依赖 App 运行状态，变成由系统负责调度的原生通知；正确的接法是：**UI → Notifier → ReminderService → AwesomeNotificationService → 插件**。

