# WebDAV 后台自动同步架构设计方案

## 1. 项目现有架构概览

- **Flutter + Riverpod**：状态管理和依赖注入
- **Sqflite 本地数据库**：Todo、提醒、标签等本地存储
- **ReminderService**：管理本地通知与系统日历同步
- **WebDAVSyncService**：负责云端同步逻辑
- **垃圾桶与软删除机制**：支持恢复已删除代办
- **系统日历同步**：可选，通过 device_calendar_plus 插件实现

## 2. 新增需求

实现 **后台自动同步 WebDAV**，即使用户未打开 App 或 App 被杀掉，也能按照设定时间间隔执行同步任务。

## 3. 后台同步架构设计

### 3.1 核心组件

1. **BackgroundSyncService**
   - 封装后台任务调度逻辑
   - 对接 native_workmanager 插件，提供周期性任务注册、取消、手动触发
   - 只操作数据层，不直接操作 UI

2. **WebDAVSyncService**
   - 现有同步逻辑保持不变
   - 提供接口供 BackgroundSyncService 调用
   - 负责数据对比、冲突处理、增量同步

3. **TodoRepository / Database Layer**
   - 提供 CRUD 接口
   - 支持软删除、恢复、清理垃圾桶
   - 后台同步通过 repository 接口操作本地数据

4. **SettingsService**
   - 存储用户设置的同步间隔（例如 15 分钟、1 小时、3 小时、6 小时、每天）
   - 允许用户随时修改间隔，后台任务动态更新

### 3.2 流程概览

```text
+-----------------+        +--------------------+
| App / UI 层     |        | SettingsService    |
+-----------------+        +--------------------+
         |                           |
         | 用户修改同步间隔           | 保存设置
         v                           v
+-----------------+        +--------------------+
| BackgroundSyncService  |  注册/取消周期任务   |
+-----------------+        +--------------------+
         |
         v
+-----------------+
| WebDAVSyncService |
+-----------------+
         |
         v
+-----------------+
| TodoRepository   |
+-----------------+
         |
         v
+-----------------+
| Sqflite Database |
+-----------------+
```

### 3.3 调度机制

- **Android**：通过 native_workmanager 插件注册周期任务，系统保证任务在后台运行，即使 App 被杀也能触发
- **iOS**：通过 Background Fetch 机制实现周期性同步，系统可能延迟或合并任务
- **任务执行**：任务回调只操作 Repository / Service 层，不依赖 UI

### 3.4 数据一致性与安全

- **事务操作**：同步任务操作数据库时使用事务，保证本地数据一致性
- **冲突处理**：遵循现有 WebDAVSyncService 的冲突解决策略
- **错误处理**：任务异常捕获并写入日志或本地状态表，以便下次重试

### 3.5 用户配置

- 在设置页增加“后台自动同步间隔”选项
- 可选值：15 分钟、30 分钟、1 小时、3 小时、6 小时、每天、从不
- 修改间隔时 BackgroundSyncService 自动取消旧任务并注册新任务

## 4. 注意事项

- iOS 限制：完全杀掉 App 时，Background Fetch 任务可能延迟或不触发
- Android 任务需考虑系统 Doze 模式影响，可使用 preciseAlarm / ExistingWorkPolicy 保证周期执行
- 任务逻辑只允许操作数据层，不要直接操作 UI
- 与 ReminderService、系统日历同步逻辑互不干扰，保持独立

## 5. 总结

- **目标**：即使应用关闭，也能按照用户设定间隔自动同步 WebDAV
- **实现方式**：新增 BackgroundSyncService，通过 native_workmanager 调度周期任务，调用现有 WebDAVSyncService，同步数据到本地数据库
- **好处**：不破坏现有业务逻辑，保持 UI 与业务分离，同时提供稳定后台同步能力
- **平台注意**：Android 完全支持，iOS 受系统限制，可能延迟

```text
整个架构图：

[UI / Settings] -> SettingsService -> BackgroundSyncService -> WebDAVSyncService -> TodoRepository -> Sqflite Database
```