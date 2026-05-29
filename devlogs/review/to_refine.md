# AudioNotes 潜在冗余与逻辑问题

> 基于 v1.6.6 代码库审查，识别架构冗余、逻辑矛盾、代码重复及潜在缺陷。

---

## 一、架构冗余

### 1. ASR 服务双通道并存
- **`ASRPlatformService`**（MethodChannel: `com.audionotes/asr`）实现了实时流式识别（partialTranscript / finalSegment 事件流）
- **`RecorderService`**（MethodChannel: `com.audionotes/recorder`）+ **`RecognitionService`**（MethodChannel: `com.audionotes/recognition`）实现了"先录音后识别"的离线流程
- **问题**：两套通道功能高度重叠，ASRPlatformService 似乎是为早期实时流式方案设计的，但当前主流程已完全走 RecorderService + RecognitionService 的离线模式。ASRPlatformService 仅在代码中声明，未在主流程中实际使用。
- **建议**：明确统一为一种方案。若放弃实时流式方案，可移除 ASRPlatformService 及其相关事件流；若计划恢复，应标注为实验性功能。

### 2. CreateTodoFromRecordingUseCase 未被使用
- `lib/domain/usecases/create_todo_from_recording_usecase.dart` 定义了完整的"录音→识别→创建 Todo"用例
- 虽然在 `app_providers.dart` 中注册了 `createTodoUseCaseProvider`，但**主流程（RecordingNotifier.stop → _recognizeRecordingInBackground）并未调用此 UseCase**，而是直接在 Notifier 中内联了全部逻辑
- **问题**：UseCase 层形同虚设，违反 Clean Architecture 的用例隔离原则。业务逻辑被嵌入 Provider/Notifier，使得测试和复用困难。
- **建议**：将 `_recognizeRecordingInBackground` 中的识别逻辑迁移至 CreateTodoFromRecordingUseCase，或删除该 UseCase 并承认当前架构省略了 Domain 层。

### 3. 置信度计算逻辑重复
- `RecordingNotifier._recognizeRecordingInBackground` 中有一套详细的置信度计算（文本启发 + 音频质量 + ASR 置信度加权）
- `CreateTodoFromRecordingUseCase.execute` 中有一套简化的置信度计算（仅文本启发）
- **问题**：两处逻辑不一致且重复，若 UseCase 被启用将产生不同结果。
- **建议**：提取为独立的 `ConfidenceCalculator` 工具类，统一调用。

### 4. 文本后处理逻辑重复
- 识别后的文本处理（空白归一化、CJK 去空格、句末标点补全、自动移除句号）在以下两处重复实现：
  - `RecordingNotifier._recognizeRecordingInBackground`（约 30 行处理逻辑）
  - `CreateTodoFromRecordingUseCase.execute`（约 10 行简化版）
- **建议**：提取为 `TranscriptPostProcessor` 工具类。

---

## 二、逻辑矛盾

### 5. partialTranscriptProvider 无数据源
- `partialTranscriptProvider` 和 `PartialTranscriptNotifier` 在 `app_providers.dart` 中定义
- `RecordingOverlay` 中使用了 `partialTranscriptProvider`
- 但当前的 RecorderService + RecognitionService 离线流程**不产生实时部分转录**，录音结束后才开始识别
- **问题**：部分转录功能在当前架构下无法工作，Overlay 可能始终显示空字符串
- **建议**：要么恢复 ASRPlatformService 的实时流式识别，要么移除 partialTranscriptProvider 和 Overlay 中的实时转录 UI。

### 6. 录音状态与识别状态不一致
- `RecordingState` 枚举（idle/recording/recognizing/completed/failed）存在于 Provider 层
- `TodoTaskState` 枚举（recording/recognizing/ready/failed）存在于 Model 层
- **问题**：两个枚举表示相似的 Lifecycle 但定义不同步。`RecordingState.recognizing` 表示"正在识别中"，而 `TodoTaskState.recognizing` 也表示相同含义，但 `RecordingState` 在识别开始后立即回到 `idle`（见 `RecordingNotifier.stop()`），这导致用户无法从全局状态判断当前是否有识别任务在进行。
- **建议**：统一生命周期语义，或在 RecordingState 中增加 `backgroundRecognizing` 状态。

### 7. sortTodosInBackground 死代码
- `TodoGroupingService.sortTodosInBackground` 使用 `compute` 在后台 isolate 排序
- `_backgroundSortPayload` 是顶层函数但代码中**未找到其定义**（仅看到调用处）
- 整个方法在主流程中从未被调用
- **问题**：后台排序优化未生效，当 Todo 数量较大时可能存在 UI 卡顿。
- **建议**：要么在 TodoListNotifier.loadTodos 中启用后台排序，要么移除此死代码。

### 8. groupOrderMap 双重存储
- `HomeScreen._groupOrderMap` 是 State 级别的本地变量
- `groupOrderMapProvider` 是全局 Riverpod 状态
- 两者在 `_loadGroupOrder()` 中同步设置，在 `updateGroupOrderMap()` 中也同步设置
- **问题**：同一数据存储在两处，增加了不一致风险，且 try-catch 吞掉了 provider 不可用的异常。
- **建议**：完全使用 Riverpod provider 管理分组顺序，移除 State 级别的冗余副本。

---

## 三、代码质量问题

### 9. Provider 中直接访问 DatabaseHelper
- `TodoListNotifier.updateText()` 方法直接通过 `DatabaseHelper.instance` 操作数据库：
  ```dart
  final dbHelper = DatabaseHelper.instance;
  final todo = await dbHelper.getTodoById(id);
  ```
- 这绕过了 Repository 层，违反分层架构。
- **建议**：统一通过 `TodoRepository` 操作数据。

### 10. SettingsService 每次构建时实例化
- `main.dart` 的 `build` 方法中：
  ```dart
  final settingsService = SettingsService();
  ```
- 每次 UI rebuild 都创建新的 SettingsService 实例（虽然无状态，但浪费）
- **建议**：将 SettingsService 注册为 Riverpod Provider 或缓存为单例。

### 11. 大量 print 调试语句
- 几乎所有 Service 和 Repository 中使用 `print()` 进行日志输出
- 生产环境中这些语句不应存在
- **建议**：引入 `logger` 包或条件编译 `debugPrint`，Release 模式下自动禁用。

### 12. 异常处理不一致
- 部分代码使用 `try-catch` 并 `rethrow`（如 RecognitionService）
- 部分代码使用 `try-catch` 并静默吞掉异常（如 `_loadGroupOrder` 中的 `catch (_) {}`）
- 部分代码仅 `print` 错误但不抛出
- **建议**：制定统一的异常处理策略，关键错误应向上传播，非关键错误应有结构化日志。

### 13. 硬编码模型版本字符串
- `'vosk-model-small-cn-0.22'` 在多处硬编码：
  - `RecordingNotifier._recognizeRecordingInBackground`
  - `CreateTodoFromRecordingUseCase.execute`
  - `HomeScreen._checkModelStatus`
- **问题**：若切换模型，需在多处同步修改。
- **建议**：从设置或模型管理器中动态获取当前模型名称。

---

## 四、数据层问题

### 14. Todo ID 使用时间戳
- `TodoItem.id` 使用 `DateTime.now().millisecondsSinceEpoch.toString()`
- **问题**：毫秒级时间戳在高频操作下可能重复（极端情况），且无法保证唯一性。
- **建议**：项目已引入 `uuid` 包，应使用 UUID v4 替代。

### 15. reminders 表 UNIQUE 约束冲突
- `reminders` 表中 `todo_id` 和 `notification_id` 都有 UNIQUE 约束
- 这意味着一个 Todo 只能有一个 Reminder，一个 notification_id 只能关联一个 Todo
- 但 `TodoRepeatType.daily/weekly` 的重复提醒需要同一 Todo 关联多个通知
- **问题**：当前表结构不支持重复提醒的多通知需求
- **建议**：移除 `todo_id` 的 UNIQUE 约束，改为允许一个 Todo 关联多个 reminder 记录。

### 16. rawTranscript 值等于 text
- `TodoRepository.completeRecognition` 中：
  ```dart
  rawTranscript: text,  // 与 text 相同
  ```
- **问题**：rawTranscript 的设计意图是保留 Vosk 原始输出（含标点、空格等），但当前实现与处理后的 text 相同，失去了对比价值。
- **建议**：在处理文本之前先保存原始识别结果到 rawTranscript。

### 17. 软删除数据无自动清理
- `deletedAt` 字段标记了删除时间，但无定期清理逻辑
- 软删除的 Todo 及其音频文件将无限占用存储空间
- **建议**：添加设置项让用户选择保留期限，或提供手动清理已删除项目的功能。

---

## 五、UI/UX 逻辑问题

### 18. pinned 字段未在 UI 生效
- `TodoItem.pinned` 字段存在于数据模型和数据库中
- `updatePinned()` 方法在 Repository 中已实现
- **但 UI 中没有置顶按钮、置顶图标，排序也未将置顶项优先排列**
- **建议**：实现置顶 UI 或移除该字段。

### 19. repeatRule 字段无 UI 入口
- `TodoItem.repeatRule` 字段存在但无任何 UI 设置界面
- `updateRepeatRule()` 方法存在但从未被调用
- **建议**：实现重复规则的 UI 设置，或移除该字段。

### 20. durationMs 未展示
- `TodoItem.durationMs` 保存了音频时长
- **但 TodoItemCard 中未展示音频时长信息**
- **建议**：在卡片上显示录音时长，或至少在详情/编辑界面展示。

### 21. meta 字段无使用场景
- `TodoItem.meta` 是一个自由文本字段
- 无任何代码写入或读取该字段
- **建议**：明确使用场景或移除。

### 22. RecordingOverlay 在离线识别模式下意义受限
- 当前 Overlay 显示录音状态和"部分转录"
- 但离线识别模式下没有实时转录数据
- **建议**：简化为纯录音状态指示器，或恢复实时流式识别。

---

## 六、性能隐患

### 23. loadTodos 全量刷新
- 几乎所有操作（toggleStatus、updateText、reorder 等）最终都调用 `loadTodos()` 全量重新加载
- 随 Todo 数量增长，这会导致不必要的数据库查询和 UI 重建
- **建议**：改为局部更新（在内存中修改列表，仅必要时全量刷新）。

### 24. tagsForTodoProvider 逐 Todo 请求
- 每个 TodoItemCard 都通过 `tagsForTodoProvider(todo.id)` 独立查询标签
- 在列表视图下，N 个 Todo 产生 N 次数据库查询
- **建议**：批量预加载标签数据，或在 loadTodos 时一并获取所有关联标签。

### 25. getAvailableStorage 硬编码返回值
- `ModelManagerService.getAvailableStorage()` 硬编码返回 `1073741824`（1GB）
- **问题**：无法反映真实存储状态，可能导致下载模型时空间不足
- **建议**：使用平台 API 获取实际可用存储空间。

---

## 七、潜在运行时错误

### 26. _backgroundSortPayload 未定义
- `sortTodosInBackground` 调用 `compute(_backgroundSortPayload, payload)`
- 但 `_backgroundSortPayload` 顶层函数在可见代码中未定义
- **问题**：若被调用将导致编译错误或运行时崩溃
- **建议**：补全定义或删除此方法。

### 27. ASRPlatformService 事件流未关闭
- `ASRPlatformService._eventController` 是 broadcast StreamController
- `dispose()` 方法存在但从未被调用
- **问题**：如果 ASRPlatformService 实例被替换，旧的 StreamController 不会被关闭
- **建议**：在 Provider 的 onDispose 中调用 dispose()。

### 28. 录音取消后的占位 Todo 清理
- `RecordingNotifier` 中 `_replacementTodoId` 和 `_replacementOldAudioPath` 在 `stop()` 中清空
- 但若 `cancelRecording()` 被调用，这些字段不会重置
- **问题**：取消录音后再录新音可能错误地替换旧 Todo
- **建议**：在取消录音时也清空替换相关字段。
