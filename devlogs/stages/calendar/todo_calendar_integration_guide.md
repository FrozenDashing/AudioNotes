# Flutter Todo 提醒系统升级指导文档

## 1️⃣ 架构设计思路

### 核心理念
- **Job / Todo** 是中心对象，每条 Todo 仍然包含：
  - `title`
  - `description`
  - `dueAt`（截止时间）
  - `remindAt`（提醒时间）

- **提醒方式可切换**：
  - `NotificationMode.local` → 使用 `flutter_local_notifications`
  - `NotificationMode.calendar` → 使用 `device_calendar_plus` 写入系统日历

- **映射表**：
  - `todo.id ↔ calendarEventId`，保证更新/删除时可同步对应系统日历事件

### 服务层划分
1. **ReminderService**
   - 当前已经处理本地通知
   - 扩展接口：
     ```dart
     Future<void> scheduleReminder(Todo todo);
     Future<void> updateReminder(Todo todo);
     Future<void> cancelReminder(Todo todo);
     ```
   - 根据 `NotificationMode` 决定使用本地通知还是系统日历

2. **CalendarSyncService**（新增）
   - 封装 `device_calendar_plus` 相关逻辑
   - CRUD 日历事件
   - 处理时区、重复提醒等
   - 返回 `eventId` 存入 Todo 表或映射表

3. **SettingsService**
   - 存储用户选择的提醒方式
   - 切换时可以重建提醒（删除旧模式、创建新模式）

---

## 2️⃣ CalendarSyncService 示例

```dart
import 'package:device_calendar_plus/device_calendar_plus.dart';

class CalendarSyncService {
  final DeviceCalendarPlugin _calendarPlugin = DeviceCalendarPlugin();

  Future<String?> createEvent(Todo todo) async {
    final permissions = await _calendarPlugin.hasPermissions();
    if (permissions.isSuccess && !permissions.data!) {
      await _calendarPlugin.requestPermissions();
    }

    final calendarsResult = await _calendarPlugin.retrieveCalendars();
    final defaultCalendar = calendarsResult.data!.first;

    final event = Event(
      defaultCalendar.id,
      title: todo.title,
      description: todo.description,
      start: todo.remindAt,
      end: todo.dueAt,
      reminders: [Reminder(minutes: 0)],
    );

    final createResult = await _calendarPlugin.createOrUpdateEvent(event);
    return createResult?.data; // 返回eventId
  }

  Future<void> updateEvent(Todo todo, String eventId) async {
    final event = Event(eventId)
      ..title = todo.title
      ..description = todo.description
      ..start = todo.remindAt
      ..end = todo.dueAt;
    await _calendarPlugin.createOrUpdateEvent(event);
  }

  Future<void> deleteEvent(String eventId) async {
    await _calendarPlugin.deleteEvent(eventId);
  }
}
```

---

## 3️⃣ ReminderService 改造示例

```dart
enum NotificationMode { local, calendar }

class ReminderService {
  final CalendarSyncService _calendarService = CalendarSyncService();
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  NotificationMode mode;

  ReminderService({required this.mode});

  Future<void> scheduleReminder(Todo todo) async {
    if (mode == NotificationMode.local) {
      await _scheduleLocalNotification(todo);
    } else if (mode == NotificationMode.calendar) {
      final eventId = await _calendarService.createEvent(todo);
      todo.calendarEventId = eventId;
      // 更新DB映射
    }
  }

  Future<void> updateReminder(Todo todo) async {
    if (mode == NotificationMode.local) {
      await _updateLocalNotification(todo);
    } else if (mode == NotificationMode.calendar && todo.calendarEventId != null) {
      await _calendarService.updateEvent(todo, todo.calendarEventId!);
    }
  }

  Future<void> cancelReminder(Todo todo) async {
    if (mode == NotificationMode.local) {
      await _cancelLocalNotification(todo);
    } else if (mode == NotificationMode.calendar && todo.calendarEventId != null) {
      await _calendarService.deleteEvent(todo.calendarEventId!);
    }
  }

  // 本地通知封装...
  Future<void> _scheduleLocalNotification(Todo todo) async { /*...*/ }
  Future<void> _updateLocalNotification(Todo todo) async { /*...*/ }
  Future<void> _cancelLocalNotification(Todo todo) async { /*...*/ }
}
```

---

## 4️⃣ 设置切换逻辑

```dart
Future<void> switchNotificationMode(NotificationMode newMode) async {
  final todos = await todoRepository.getAllTodos();
  
  for (var todo in todos) {
    await reminderService.cancelReminder(todo); // 取消旧模式
    reminderService.mode = newMode;
    await reminderService.scheduleReminder(todo); // 创建新模式
  }

  currentMode = newMode;
  await settingsService.saveNotificationMode(newMode);
}
```

---

## 5️⃣ 注意事项

1. **权限管理**
   - iOS: `NSCalendarsUsageDescription`
   - Android: `READ_CALENDAR` / `WRITE_CALENDAR`

2. **时区处理**
   - 本地通知使用 `timezone` 包
   - 日历事件使用 `device_calendar_plus` 的 `DateTime`（支持时区）

3. **事件映射**
   - Todo 表增加 `calendarEventId` 字段，避免重复事件

4. **提醒时间逻辑**
   - 如果 `remindAt > dueAt` → 自动调整或禁用提醒

5. **重复事件**
   - `device_calendar_plus` 支持 recurrence rules，可用于周期性 Todo

