# AudioNotes API 交互架构

## 概述
AudioNotes 应用程序实现了分层架构，在前端 UI 组件和后端处理服务之间有明确的分离。API 交互遵循反应式模式，使用 Riverpod 状态管理，并通过平台通道进行原生操作的额外通信。

## 前端-后端通信层

### 1. Riverpod 状态管理层
UI 和业务逻辑之间的主要通信机制使用 Riverpod 提供者：

```
UI 层 (小部件) ←→ Riverpod 提供者 ←→ 服务层 ←→ 数据层
```

#### 使用的提供者类型：
- **Provider**: 用于单例服务和存储库
- **NotifierProvider**: 用于可变状态（录音状态、部分转录）
- **AsyncNotifierProvider**: 用于异步数据（待办事项列表、类别、标签）
- **FutureProvider**: 用于一次性异步操作（加载列表）

### 2. 服务层接口
通过专用提供者访问后端服务：

```
[recorderServiceProvider](lib/providers/app_providers.dart#L141-L143) ←→ RecorderService (音频录制)
[recognitionServiceProvider](lib/providers/app_providers.dart#L153-L155) ←→ RecognitionService (语音识别)
[todoRepositoryProvider](lib/providers/app_providers.dart#L52-L54) ←→ TodoRepository (待办事项数据操作)
[databaseHelperProvider](lib/providers/app_providers.dart#L49-L51) ←→ DatabaseHelper (SQLite 操作)
[modelManagerServiceProvider](lib/providers/app_providers.dart#L159-L161) ←→ ModelManagerService (Vosk 模型管理)
```

## API 交互流程

### 1. 录音过程 API 流程
```
UI (HomeScreen) → [recordingStateProvider](lib/providers/app_providers.dart#L276-L278).start() → RecorderService.startRecording() → 原生平台通道 → 音频录制 → [recordingStateProvider](lib/providers/app_providers.dart#L276-L278) → UI 更新
```

#### 详细步骤：
1. 用户在 UI 中按下录音按钮
2. UI 调用 `recordingStateProvider.notifier.start()`
3. RecordingNotifier.start() 调用 RecorderService.startRecording()
4. RecorderService 通过平台通道与原生层通信
5. 原生层捕获音频并保存到文件
6. 录音状态更新为"录音中"
7. UI 更新以反映录音状态
8. 部分转录流到 [partialTranscriptProvider](lib/providers/app_providers.dart#L289-L291)
9. UI 更新实时转录

### 2. 识别过程 API 流程
```
UI (HomeScreen) → [recordingStateProvider](lib/providers/app_providers.dart#L276-L278).stop() → RecognitionService.recognize() → 原生 ASR → 识别结果 → TodoRepository.insert() → DatabaseHelper.insertTodo() → [todoListProvider](lib/providers/app_providers.dart#L774-L777) → UI 刷新
```

#### 详细步骤：
1. 用户停止录音
2. RecordingNotifier.stop() 获取音频文件路径
3. RecognitionService 使用 Vosk 识别音频
4. 识别结果包含文本和置信度
5. TodoRepository 使用音频路径和识别文本创建待办事项
6. DatabaseHelper 将待办事项插入 SQLite 数据库
7. [todoListProvider](lib/providers/app_providers.dart#L774-L777) 从数据库刷新
8. UI 更新以显示新待办事项

### 3. 待办事项管理 API 流程
```
UI (TodoItemCard) → [todoListProvider](lib/providers/app_providers.dart#L774-L777).notifier → TodoRepository → DatabaseHelper → SQLite 数据库 → [todoListProvider](lib/providers/app_providers.dart#L774-L777) → UI 更新
```

#### 支持的操作：
- **切换完成**: `todoListProvider.notifier.toggleStatus()` → `TodoRepository.toggleStatus()` → `DatabaseHelper.updateTodo()`
- **更新文本**: `todoListProvider.notifier.updateText()` → `DatabaseHelper.updateTodo()`
- **删除待办事项**: `todoListProvider.notifier.deleteTodo()` → `DatabaseHelper.deleteTodo()`
- **重新排序待办事项**: `todoListProvider.notifier.reorderTodos()` → `DatabaseHelper.updateOrderIndices()`
- **更新优先级**: `todoListProvider.notifier.updatePriority()` → `DatabaseHelper.updatePriority()`
- **更新提醒**: `todoListProvider.notifier.updateReminderTime()` → `DatabaseHelper.upsertReminder()`

## 原生平台通信

### 平台通道接口
应用程序使用平台通道与原生音频录制和 ASR 功能通信：

```
Dart 层 ↔ MethodChannel ↔ 原生层 (Android/iOS)
```

#### 可用方法：
- `startRecording`: 开始音频捕获
- `stopRecording`: 结束音频捕获并返回文件路径
- `cancelRecording`: 取消正在进行的录音
- `reRecord`: 替换现有待办事项的音频
- `reloadModel`: 重新加载 ASR 模型
- `isModelReady`: 检查 ASR 模型是否已加载

#### 事件流：
- `partial_transcript`: 实时部分识别结果
- `final_segment`: 完成的识别段
- `recording_status`: 录音状态更新

## 数据流模式

### 1. 读取操作
```
UI 小部件 → Riverpod Consumer → 提供者 → 存储库 → DatabaseHelper → SQLite → 存储库 → 提供者 → UI 小部件
```

### 2. 写入操作
```
UI 小部件 → Riverpod Consumer → 提供者.notifier → 存储库 → DatabaseHelper → SQLite → 存储库 → 提供者 → UI 更新
```

### 3. 异步操作
```
UI 小部件 → FutureProvider → 存储库 → DatabaseHelper → SQLite → 结果 → FutureProvider → UI 小部件
```

## API 交互中的错误处理

### 前端错误处理
- UI 使用 SnackBar 显示错误消息
- 失败操作的优雅回退状态
- 临时故障的重试机制

### 后端错误处理
- 存储库层捕获和处理数据库错误
- 服务层管理原生平台通信错误
- 提供者层向 UI 组件传播错误

## 性能考虑

### 状态更新优化
- 使用特定提供者的细粒度状态更新
- 多个更改的批处理操作
- 计算密集型操作的后台处理

### 数据一致性
- 事务型数据库操作
- 相关数据的原子更新
- UI 和数据库之间的状态同步

此 API 交互架构确保了关注点的清晰分离，同时保持了应用程序所有层之间的高效通信。