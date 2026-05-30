# device_calendar_plus 使用参考（面向 AI 的用例说明）

> 目标：帮助 AI 快速理解 `device_calendar_plus` 在 Flutter Todo / Reminder 项目中的正确用法、适用场景、调用顺序和常见坑点。
>
> 来源：基于 `device_calendar_plus` 官方 pub.dev 文档整理。该插件是一个维护中的 Flutter 原生日历插件，支持 Android 和 iOS，面向日历事件读写场景。  
> 适用平台：Android（minSdk 24+）、iOS（13+）。

---

## 1. 插件定位

`device_calendar_plus` 适合做“**与系统日历深度集成**”的功能，而不是单纯的本地提醒。

它可以做的事情包括：

- 请求和检查日历权限
- 读取、创建、更新、删除日历
- 读取、创建、更新、删除事件
- 读取指定时间范围内的事件
- 打开系统原生事件编辑器
- 支持 all-day 事件
- 支持时区正确处理
- 支持重复事件（daily / weekly / monthly / yearly）
- 支持编辑 / 删除重复系列中的全部、当前这一项、当前及之后

---

## 2. 适合的业务场景

### 场景 A：Todo 与系统日历同步
适合把 Todo 的 `dueAt` / `remindAt` 写入系统日历事件中。

推荐映射：

- `todo.title` -> `event.title`
- `todo.description` -> `event.description`
- `todo.dueAt` -> `event.startDate` 或 `event.endDate`
- `todo.remindAt` -> 事件提醒逻辑由系统日历自行处理，或在本地保存提醒时间作为业务字段
- `todo.id` -> `event.instanceId` 或 `eventId` 映射表
- `todo.isAllDay` -> `event.isAllDay`

### 场景 B：用户主动在系统日历里编辑
当用户希望“在系统日历里看见并修改任务”，可用插件打开原生编辑器：

- 新建事件编辑器
- 查看事件详情
- 编辑事件

### 场景 C：周期性任务
例如：

- 每天喝药
- 每周复盘
- 每月还款
- 每年生日提醒

这种场景适合使用 recurring event。

---

## 3. 调用顺序建议

### 3.1 初始化
业务代码中先拿到单例：

```dart
final plugin = DeviceCalendar.instance;
```

### 3.2 检查权限
先检查，再请求，避免一上来就弹权限框：

```dart
final status = await plugin.hasPermissions();
if (status == CalendarPermissionStatus.notDetermined) {
  final newStatus = await plugin.requestPermissions();
}
```

### 3.3 选择目标日历
推荐先读取日历列表，再挑一个可写日历：

```dart
final calendars = await plugin.listCalendars();
final writable = calendars.firstWhere((cal) => !cal.readOnly);
```

如果需要创建新日历，可先读取 sources，再创建到指定账号。

### 3.4 创建事件
创建时传入：

- `calendarId`
- `title`
- `startDate`
- `endDate`
- 可选：`description`, `location`, `timeZone`, `isAllDay`, `availability`, `recurrenceRule`

### 3.5 更新事件
更新单个事件时，使用 `instanceId`。

### 3.6 删除事件
删除单个事件时，通常也是用 `instanceId`。

### 3.7 读取事件
用于刷新列表、同步状态、回填 UI。

---

## 4. 关键 API 用例

## 4.1 请求权限

```dart
final plugin = DeviceCalendar.instance;
final status = await plugin.requestPermissions();
if (status != CalendarPermissionStatus.granted) {
  // 用户拒绝，提示去系统设置打开权限
}
```

### 适用场景
- App 首次打开系统日历功能
- 用户切换到“系统日历同步模式”
- 用户从设置页手动开启日历同步

---

## 4.2 检查权限

```dart
final plugin = DeviceCalendar.instance;
final status = await plugin.hasPermissions();
```

### 适用场景
- 页面初始化时静默检查
- 同步前预检
- 避免重复弹窗

---

## 4.3 读取日历列表

```dart
final plugin = DeviceCalendar.instance;
final calendars = await plugin.listCalendars();
```

### 适用场景
- 选择默认写入日历
- 让用户选择同步到哪个日历
- 显示可用日历来源

### 建议
- 优先选择 `readOnly == false` 的日历
- 若有主日历，可优先写入主日历
- 写入前最好保存 `calendarId`

---

## 4.4 读取来源（sources）

```dart
final sources = await plugin.listSources();
```

### 适用场景
- 创建新日历时，指定 iCloud / Google / 本地账号
- 提供高级设置：用户选择同步到哪个账号

### 建议
- 普通 Todo 应用通常不需要暴露太多源选择
- 默认写入一个“应用可写”的日历即可

---

## 4.5 创建日历

```dart
final calendarId = await plugin.createCalendar(name: 'My Calendar');
```

### 适用场景
- 你的应用希望独占一个“Task Calendar”
- 需要把 todo 统一写入独立日历
- 需要颜色、账号隔离

### 建议
- 给 Todo 应用单独建一个日历，便于管理
- 存储 `calendarId`
- 后续所有事件都写入这个日历

---

## 4.6 创建事件

```dart
final eventId = await plugin.createEvent(
  calendarId: 'your-calendar-id',
  title: 'Team Meeting',
  startDate: DateTime(2024, 3, 20, 14, 0),
  endDate: DateTime(2024, 3, 20, 15, 0),
);
```

### 适用场景
- Todo 的截止时间同步到系统日历
- 提醒时间同步为一个日历事件
- 用户在系统日历里可见该任务

### Todo 映射建议
- Todo 的主标题 -> 事件标题
- Todo 备注 -> 事件描述
- Todo 截止时间 -> 事件开始/结束
- Todo 优先级 -> 可写入描述或标题前缀
- Todo 的唯一 ID -> 本地映射表保存 `eventId`

---

## 4.7 创建全天事件

```dart
final allDayEventId = await plugin.createEvent(
  calendarId: 'your-calendar-id',
  title: 'Conference',
  startDate: DateTime(2024, 3, 20),
  endDate: DateTime(2024, 3, 21),
  isAllDay: true,
);
```

### 适用场景
- 只关心日期，不关心具体时分秒
- 生日、节日、整日待办、假期

### 注意
- all-day 事件是“浮动日期”，不是某一时刻
- 不要强行转 UTC
- 显示时应保留年月日

---

## 4.8 创建带时区的事件

```dart
final detailedEventId = await plugin.createEvent(
  calendarId: 'your-calendar-id',
  title: 'Project Kickoff',
  startDate: DateTime(2024, 3, 20, 10, 0),
  endDate: DateTime(2024, 3, 20, 12, 0),
  description: 'Quarterly project kickoff meeting',
  location: 'Conference Room A',
  timeZone: 'America/New_York',
  availability: EventAvailability.busy,
);
```

### 适用场景
- 需要跨时区稳定显示的工作安排
- 出差、远程会议、国际协作任务

### 建议
- 仅在确实需要时指定时区
- 普通本地 Todo 可以直接用本地时间

---

## 4.9 创建重复事件

```dart
await plugin.createEvent(
  calendarId: calendarId,
  title: 'Daily Standup',
  startDate: DateTime(2024, 3, 20, 9, 0),
  endDate: DateTime(2024, 3, 20, 9, 15),
  recurrenceRule: DailyRecurrence(end: CountEnd(30)),
);
```

### 适用场景
- 每天、每周、每月、每年重复的任务
- 例如“每天 9 点提醒喝水”

### 常见规则
- `DailyRecurrence`
- `WeeklyRecurrence`
- `MonthlyRecurrence`
- `YearlyRecurrence`

### 建议
- Todo 业务里，把“重复规则”独立建模
- 不要把重复逻辑写死在标题里

---

## 4.10 读取单个事件

```dart
final event = await plugin.getEvent(event.instanceId);
```

### 适用场景
- 刷新某条同步记录
- 恢复系统日历中的事件状态
- 查看某个 todo 对应的日历事件是否还存在

### 注意
- 对重复事件，`instanceId` 表示某个具体 occurrence
- `eventId` 和 `instanceId` 不要混用

---

## 4.11 读取事件列表

```dart
final now = DateTime.now();
final events = await plugin.listEvents(
  now,
  now.add(const Duration(days: 30)),
);
```

### 适用场景
- 同步未来 30 天的日历事件到本地
- 展示日历视图
- 做任务日程聚合

### 建议
- 使用时间范围查询，不要一次性拉全量
- 对大数据量账号，范围查询更稳

---

## 4.12 打开原生日历编辑器

### 新建编辑器

```dart
await plugin.showCreateEventModal();
```

### 预填数据打开

```dart
await plugin.showCreateEventModal(
  title: 'Team Meeting',
  startDate: DateTime.now().add(const Duration(hours: 1)),
  endDate: DateTime.now().add(const Duration(hours: 2)),
  location: 'Conference Room A',
  description: 'Weekly sync',
);
```

### 适用场景
- 想把“是否保存”交给用户自己确认
- 想利用系统原生 UI，减少自绘编辑页
- iOS 上添加 attendees 时可用原生编辑器作为 workaround

---

## 4.13 查看 / 编辑原生事件详情

```dart
await plugin.showEventModal(event.instanceId);
```

### 适用场景
- 点击某个 todo，打开系统日历详情
- 用户希望直接在系统日历里编辑
- 需要与原生日历 UI 保持一致

---

## 4.14 更新事件

```dart
await plugin.updateEvent(
  instanceId: event.instanceId,
  title: 'Updated Meeting Title',
);
```

### 适用场景
- Todo 标题改了
- 截止时间改了
- 描述改了
- 位置改了

### 建议
- 以 `instanceId` 更新具体事件
- 本地 todo 更新后，立即同步到系统日历

---

## 4.15 更新重复事件

### 更新整个系列

```dart
await plugin.updateRecurring(
  event.instanceId,
  EventSpan.allEvents,
  recurrenceRule: Patch.set(WeeklyRecurrence(end: CountEnd(10))),
);
```

### 仅修改这一项
```dart
await plugin.updateRecurring(
  event.instanceId,
  EventSpan.thisInstance,
  title: 'Moved this week only',
);
```

### 修改这一项以及之后的所有项
```dart
await plugin.updateRecurring(
  event.instanceId,
  EventSpan.thisAndFollowing,
  startDate: DateTime(2024, 3, 21, 15, 0),
  endDate: DateTime(2024, 3, 21, 16, 0),
);
```

### 适用场景
- 周期性 Todo 的某一次单独改动
- 从某个时间点起调整重复计划

---

## 4.16 删除事件

```dart
await plugin.deleteEvent(event.instanceId);
```

### 适用场景
- Todo 被删除时，顺带删除系统日历事件
- 用户取消同步
- 事件过期后清理

### 注意
- 对重复事件，`deleteEvent` 会删除整个系列
- 如果只想删某个 occurrence，需要用 `deleteRecurring`

---

## 4.17 删除重复事件的某一部分

```dart
await plugin.deleteRecurring(event.instanceId, EventSpan.thisInstance);
```

### 适用场景
- 只删除重复系列中的一次
- 删除某次之后的后续事件
- 删除整个系列

---

## 5. 错误处理策略

插件的错误分两类：

### 5.1 运行时错误
使用 `DeviceCalendarException` + `DeviceCalendarError`

建议处理：

- 权限拒绝
- 日历不存在
- 事件不存在
- 日历只读
- 删除失败

示例：

```dart
try {
  await plugin.createEvent(...);
} on DeviceCalendarException catch (e) {
  switch (e.errorCode) {
    case DeviceCalendarError.permissionDenied:
      // 提示用户去授权
      break;
    case DeviceCalendarError.notFound:
      // 日历或事件不存在
      break;
    default:
      // 兜底处理
      break;
  }
}
```

### 5.2 编程错误
例如参数非法、开始时间晚于结束时间、ID 为空。

这种错误是代码 bug，不是用户态错误。

---

## 6. 推荐的 Todo 集成模式

### 模式 1：本地通知模式
适合：

- 只想弹提醒
- 不需要进入系统日历
- 希望行为最轻量

### 模式 2：系统日历模式
适合：

- 希望任务出现在系统日历里
- 希望用户能在日历 app 中继续管理
- 希望桌面端、系统搜索、跨设备日历更统一

### 切换策略
- `local` 模式：继续用本地通知插件
- `calendar` 模式：用 `device_calendar_plus` 创建 / 更新 / 删除系统日历事件

---

## 7. Todo 数据映射建议

建议本地保存这些字段：

- `calendarMode`
- `calendarId`
- `calendarEventId`
- `calendarInstanceId`
- `syncedAt`
- `syncStatus`

建议在数据库中维护“todo 与事件”的稳定映射，不要只靠标题匹配。

---

## 8. AI 编码时的提示词建议

可以直接把下面这段给 AI：

> 请基于 `device_calendar_plus` 的官方 API 来实现系统日历同步，不要使用旧的 `device_calendar` 写法。  
> 初始化使用 `DeviceCalendar.instance`。  
> 创建前先检查权限，必要时请求权限。  
> 创建事件使用 `createEvent(calendarId, title, startDate, endDate, ...)`。  
> 更新单个事件使用 `updateEvent(instanceId: ...)`。  
> 删除单个事件使用 `deleteEvent(instanceId)`。  
> 如果是重复事件，使用 `updateRecurring` / `deleteRecurring` 并传入 `EventSpan`。  
> all-day 事件不要转换成 UTC。  
> 返回的时间默认按本地时区处理。  
> 请为 Todo 数据维护 `calendarId`、`calendarEventId` / `instanceId` 的映射，避免重复创建与误删。

---

## 9. 一句话总结

`device_calendar_plus` 适合做“**Todo 与系统日历的双向桥梁**”：先处理权限，再选日历，再创建/更新/删除事件；普通 Todo 用单次事件，周期性 Todo 用 recurring，全天任务用 all-day，恢复/删除时都要通过稳定 ID 做映射。

