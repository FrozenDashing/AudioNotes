可以。先给你一个结论：这次不是“某一个日历 API 小错”，而是 **AI 把日历同步、设置持久化、数据库清理三条线同时改乱了**。最先修的不是功能，而是**编译结构**，顺序错了会越修越乱。

我看了你上传的 `lib` 代码，当前最明显的错误集中在这几处：

## 先定位问题源头

### 1) `lib/services/reminder_service.dart`

这里已经出现了典型的“AI 拼接后遗症”：

* `_buildReminderBody` 被定义了两次
* `_lookup`、`_getLanguageCode`、`_loadNotificationMode` 的位置和作用域混乱
* 类末尾有多余的 `}`，导致结构提前闭合
* `_loadNotificationMode()` 里写了 `settings.notificationMode ?? ...`，但你在 `SettingsState` 里这个字段其实已经是非空的

这类错误会直接导致大量语法报错，应该作为第一优先级处理。

### 2) `lib/repositories/settings_repository.dart`

这里也有明显的拼接残留：

* `saveSettings()` 和 `saveNotificationMode()` 的代码边界混了
* `saveNotificationMode()` 后面又跟着一段重复的 `saveSettings` 片段
* 文件尾部的控制流很可能已经不完整

这会导致设置页、通知模式、垃圾桶保留期都加载失败。

### 3) `lib/data/database_helper.dart`

这个文件里软删除功能已经加进去了，但结构还不干净：

* `deleteTodo()`、`restoreTodo()`、`purgeTodoPermanently()`、`getDeletedTodos()`、`updateCalendarEventId()` 都在
* 但 `updateCalendarEventId()` 后面出现了多余的 `}`，把后面的 `category/tag` 相关方法挤出了类体
* `purgeAllDeletedTodos()` 里直接用了 `_db.execute(...)`，但这里更稳妥的是先 `final db = await database;` 再操作
* 这类错误会让数据库层“看起来有方法，实际上类已经断了”

### 4) `lib/services/calendar_sync_service.dart`

这里不是单纯语法问题，而是**插件 API 很可能用错了**。

`device_calendar_plus` 现在的官方文档显示，它是一个维护中的 Flutter 原生日历插件，支持 Android Calendar Provider 和 iOS EventKit，且文档示例是通过 `DeviceCalendar.instance` 来 `requestPermissions()`、`listCalendars()`、`createEvent()`、`updateEvent()`、`deleteEvent()` 的；它还明确写了 Android minSdk 24+、iOS 13+，并且没有 timezone 包依赖。([Dart packages][1])

你现在这份 `calendar_sync_service.dart` 里有几个高风险点：

* 用的是 `DeviceCalendarPlugin`，而官方示例是 `DeviceCalendar.instance`
* 用了 `retrieveCalendars()`，而文档示例是 `listCalendars()`
* 你手动 new 了一个超长参数的 `Event(...)`，这和文档中推荐的 `createEvent(calendarId: ..., title: ..., startDate: ..., endDate: ...)` 风格不一致
* 你把“创建事件”和“更新事件”的职责混在一个很重的本地封装里，后面很难排错

---

## 修复顺序，按这个来最省时间

### 第一步：先把编译打通

先不要管功能完整不完整，先把下面三个文件恢复成“能被 Dart analyzer 接受”的状态：

* `reminder_service.dart`
* `settings_repository.dart`
* `database_helper.dart`

目标只有一个：**消灭重复函数、额外括号、被拼接进去的残留代码**。

你可以按这个原则修：

* 每个 helper 只保留一个版本
* 每个 `class` 只在最后关闭一次
* 每个 `Future<...>` 方法只保留一个完整实现
* 所有“AI 自己写的占位实现”，例如 `// Implementation...`，先删掉

### 第二步：把提醒系统拆成两条清晰路径

你现在想要的是：

* `local`：本地通知
* `calendar`：系统日历

那 `ReminderService` 里应该只保留这两个分支，且互不污染。

建议结构是：

* `scheduleReminderForTodo(todo)`

  * `mode == local` → 调本地通知方法
  * `mode == calendar` → 调日历同步方法
* `clearReminder(todoId)`

  * `mode == local` → 取消通知
  * `mode == calendar` → 删除日历事件
* `updateReminder(todo)`

  * 只做“先清再建”或“原地更新”
  * 不要在更新里反复绕回 `scheduleReminderForTodo()` 造成递归和重复创建

### 第三步：重写 `CalendarSyncService`

这个文件建议直接按 `device_calendar_plus` 官方示例风格重写，不要继续沿用现在那套手搓 `Event(...)` 构造方式。

文档层面能确认的安全做法是：

* 权限检查用 `requestPermissions()`
* 日历列表用 `listCalendars()`
* 创建事件用 `createEvent(...)`
* 更新事件用 `updateEvent(instanceId: ...)`
* 删除事件用 `deleteEvent(eventId)` 或 `deleteRecurring(...)`
* 读取单个事件用 `getEvent(instanceId)`
  这些都是官方示例里明确展示的用法。([Dart packages][1])

你现在的代码里，最像错误根源的是：

* `retrieveCalendars()` 这个命名
* `DeviceCalendarPlugin` / `DeviceCalendar.instance` 混用
* `Event` 构造参数写得过满
* 日历事件 ID 和 `instanceId` 的职责没分清

### 第四步：统一 settings 持久化

`SettingsRepository` 里要保证：

* `loadSettings()` 只负责读取
* `saveSettings()` 只负责保存整个 `SettingsState`
* `saveNotificationMode()` 只保存单字段
* `trashAutoPurgeInterval` 和 `notificationMode` 的 key 名一致、读写一致

现在最危险的点是：**文件里存在重复保存逻辑和尾部残留代码**，这会导致设置页能打开，但保存后状态不稳定，或者直接编译不过。

### 第五步：再回头补数据库逻辑

等前面都稳定后，再检查数据库层：

* `deleteTodo()` 只做软删除
* `restoreTodo()` 恢复 `deleted_at`
* `purgeTodoPermanently()` 才真正删行
* `purgeDeletedTodosBefore()` 和 `purgeAllDeletedTodos()` 只用于垃圾桶自动清理和手动清空
* `updateCalendarEventId()` 必须在类体内部，并且和事务逻辑不冲突

---

## 我建议你按这个“修复标准”检查每个报错

### 语法类报错

优先看这些关键词：

* `Unexpected token '}'`
* `Expected a class member`
* `The method ... isn't defined`
* `Duplicate definition of ...`
* `A value of type '...' can't be returned from a method...`

这类基本都来自：

* 重复函数
* 多余括号
* 文件尾部拼接残留
* 方法名和返回值不一致

### API 类报错

重点看日历插件相关：

* `DeviceCalendarPlugin` 是否真存在于你当前依赖版本里
* `retrieveCalendars()` 是否应该改成 `listCalendars()`
* `createOrUpdateEvent()` 是否应该拆成 `createEvent()` 和 `updateEvent()`
* `updateEvent()` 是否要求 `instanceId` 而不是你自己拼的 `eventId`

官方 README 和示例里展示的是 `DeviceCalendar.instance`、`listCalendars()`、`requestPermissions()`、`createEvent()`、`updateEvent(instanceId: ...)`、`deleteEvent(...)` 这一套。([Dart packages][1])

---

## 最稳的修复策略

不要继续在“坏掉的版本”上打补丁式修补。最省时间的方式是：

1. 先恢复 `reminder_service.dart` 和 `settings_repository.dart` 到能编译
2. 再把 `calendar_sync_service.dart` 按官方示例重写
3. 再统一 `database_helper.dart` 的软删除与永久删除
4. 最后跑一遍全局搜索，把旧的日历调用全部替换掉

---

如果你愿意，我下一步可以直接按这份代码给你整理成一份 **“逐文件修复清单”**，格式会是：

* 文件名
* 具体错误点
* 应删代码
* 应保留代码
* 建议替换后的正确结构

这样你可以一边修一边对照。

[1]: https://pub.dev/packages/device_calendar_plus "device_calendar_plus | Flutter package"
