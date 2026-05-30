# AudioNotes 潜在冗余与逻辑问题

> 基于当前 v2.0.9 代码库审查，识别仍然存在的架构冗余、逻辑矛盾、代码重复及潜在缺陷。

---

## 一、架构冗余

### 1. ASR 服务双通道并存
- **`ASRPlatformService`**（MethodChannel: `com.audionotes/asr`）保留了实时流式识别（partialTranscript / finalSegment 事件流）
- **`RecorderService`**（MethodChannel: `com.audionotes/recorder`）+ **`RecognitionService`**（MethodChannel: `com.audionotes/recognition`）是当前主流程的离线识别链路
- **问题**：两套通道仍然并存，主流程实际以离线录音后识别为主，实时流式路径更像是实验性/备用实现，当前还没有统一成单一架构。
- **建议**：明确是否继续保留实时流式路径；如果保留，最好把它标为实验性并补齐数据流和生命周期管理。

### 2. CreateTodoFromRecordingUseCase 未被使用
- `lib/domain/usecases/create_todo_from_recording_usecase.dart` 定义了完整的"录音→识别→创建 Todo"用例
- 虽然在 `app_providers.dart` 中注册了 `createTodoUseCaseProvider`，但**主流程（RecordingNotifier.stop → _recognizeRecordingInBackground）并未调用此 UseCase**，而是直接在 Notifier 中内联了全部逻辑
- **问题**：UseCase 层形同虚设，违反 Clean Architecture 的用例隔离原则。业务逻辑被嵌入 Provider/Notifier，使得测试和复用困难。
- **已处理**：`RecordingNotifier._recognizeRecordingInBackground` 已改为调用 `CreateTodoFromRecordingUseCase`，识别、文本后处理和落库逻辑已迁移出 Notifier。

### 3. 置信度计算逻辑重复
- **已处理**：Todo 主流程已删除置信度计算，`TodoItem`、数据库列和同步 DTO 中的 `confidence` 字段也已移除。

### 4. 文本后处理逻辑重复
- **已处理**：识别后的文本后处理已统一收口到 `CreateTodoFromRecordingUseCase`。

---

## 二、逻辑矛盾

### 5. partialTranscriptProvider 无数据源
- **已处理**：`partialTranscriptProvider` 和 `PartialTranscriptNotifier` 已删除，`RecordingOverlay` 也不再显示实时转录文本。

### 6. 录音状态与识别状态不一致
- `RecordingState` 枚举（idle/recording/recognizing/completed/failed）存在于 Provider 层
- `TodoTaskState` 枚举（recording/recognizing/ready/failed）存在于 Model 层
- **问题**：两个枚举表示相似的 Lifecycle 但定义不同步。`RecordingState.recognizing` 表示"正在识别中"，而 `TodoTaskState.recognizing` 也表示相同含义，但 `RecordingState` 在识别开始后立即回到 `idle`（见 `RecordingNotifier.stop()`），这导致用户无法从全局状态判断当前是否有识别任务在进行。
- **建议**：统一生命周期语义，或在 RecordingState 中增加 `backgroundRecognizing` 状态。

### 7. sortTodosInBackground 仍未接入主流程
- `TodoGroupingService.sortTodosInBackground` 使用 `compute` 在后台 isolate 排序，`_backgroundSortPayload` 也已经补齐
- **已处理**：`TodoListNotifier.loadTodos` 已改为先取未排序数据，再交给 `TodoGroupingService.sortTodosInBackground` 在后台 isolate 排序。

### 8. groupOrderMap 双重存储
- `HomeScreen._groupOrderMap` 是 State 级别的本地变量
- `groupOrderMapProvider` 是全局 Riverpod 状态
- 两者在 `_loadGroupOrder()` 中同步设置，在 `updateGroupOrderMap()` 中也同步设置
- **问题**：同一数据存储在两处，增加了不一致风险，且 try-catch 吞掉了 provider 不可用的异常。
- **已解决**：完全使用 Riverpod provider 管理分组顺序，移除 State 级别的冗余副本。

---

## 三、代码质量问题

- **状态**：9、10、13 已处理；11、12 已部分修复，后续仍可继续统一治理剩余的日志与异常策略。

### 9. Provider 中直接访问 DatabaseHelper
- **已处理**：`TodoListNotifier.updateText()` 已改为通过 `TodoRepository.updateText()` 更新数据。

### 10. SettingsService 每次构建时实例化
- **已处理**：`SettingsService` 已通过 `settingsServiceProvider` 注入，`main.dart` 不再在 `build()` 中重复实例化。

### 11. 大量 print 调试语句
- 几乎所有 Service 和 Repository 中使用 `print()` 进行日志输出
- 生产环境中这些语句不应存在
- **建议**：引入 `logger` 包或条件编译 `debugPrint`，Release 模式下自动禁用。
- **已部分修复**：主录音、识别、模型、音频与仓库链路的 `print()` 已改为 `debugPrint()`，其余零散位置后续再统一收口。

### 12. 异常处理不一致
- 部分代码使用 `try-catch` 并 `rethrow`（如 RecognitionService）
- 部分代码使用 `try-catch` 并静默吞掉异常（如 `_loadGroupOrder` 中的 `catch (_) {}`）
- 部分代码仅 `print` 错误但不抛出
- **建议**：制定统一的异常处理策略，关键错误应向上传播，非关键错误应有结构化日志。
- **已部分修复**：若干静默 `catch (_) {}` 已改为可见的 `debugPrint` 日志；关键异常仍按原设计继续向上传播。

### 13. 硬编码模型版本字符串
- **已处理**：默认小模型名称已集中到 `VoskModel.chineseSmallModelName`，相关调用点改为共享常量。

---

## 四、数据层问题

### 14. Todo ID 使用时间戳
- `TodoItem.id` 使用 `DateTime.now().millisecondsSinceEpoch.toString()`
- **问题**：毫秒级时间戳在高频操作下可能重复（极端情况），且无法保证唯一性。
- **建议**：项目已引入 `uuid` 包，应使用 UUID v4 替代。
- **已处理**：在 `TodoRepository.insertRecognizing()` 中改为使用 UUID v4 生成 `TodoItem.id`（通过 `uuid` 包），替代之前的毫秒时间戳，降低 ID 冲突风险。

### 15. 重复提醒的实体模型仍不完整
- `reminders` 表仍然是“一 Todo 一提醒”的持久化模型；daily/weekly 目前通过同一 `notification_id` 做周期调度
- 这意味着表约束本身不再是当前阻塞点
- **问题**：真正缺的是“完成一次后自动推进下一轮 Todo 实体/状态”的业务闭环，而不是通知本身
- **建议**：如果重复任务要更像任务实例而不是纯通知，应该补一层重复任务调度逻辑，而不是单纯改约束。

### 16. rawTranscript 值等于 text
- `TodoRepository.completeRecognition` 中：
  ```dart
  rawTranscript: text,  // 与 text 相同
  ```
- **问题**：rawTranscript 的设计意图是保留 Vosk 原始输出（含标点、空格等），但当前实现与处理后的 text 相同，失去了对比价值。
- **建议**：在处理文本之前先保存原始识别结果到 rawTranscript。
 - **已处理**：`CreateTodoFromRecordingUseCase` 在对识别结果做归一化/去尾点之前，会先将原始识别结果作为 `rawTranscript` 传入 `TodoRepository.completeRecognition()`，然后将规范化后的文本写入 `text` 字段，从而保留原始输出用于对比或调试。
  - **相关变更**：保存 `rawTranscript` 后，代码现在会删除对应的音频文件并清空 `audioPath`（不再保留录音文件），同时在长按菜单中移除了“播放”选项以匹配此行为。

### 17. 软删除数据无自动清理
- `deletedAt` 字段标记了删除时间，但无定期清理逻辑
- 软删除的 Todo 及其音频文件将无限占用存储空间
- **已处理**：参照 [TrashTodo.md](../stages/QOL/TrashTodo.md) 的思路，把删除拆成“垃圾桶 + 永久清理”两层：主流程只做软删除并进入垃圾桶，垃圾桶页提供恢复/清空入口，再配合设置中的自动清理间隔或启动时清理，避免已删除数据长期堆积。

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
- **已处理**：`durationMs` 字段已从 `TodoItem`、数据库 schema 和保存流程中移除，不再保留或展示音频时长信息。

### 21. meta 字段无使用场景
- `TodoItem.meta` 是一个自由文本字段
- 无任何代码写入或读取该字段
- **建议**：明确使用场景或移除。

### 22. RecordingOverlay 在离线识别模式下意义受限
- **已处理**：Overlay 已简化为纯录音/处理中状态指示器，不再展示实时转录文本。

---

## 六、性能隐患

### 23. loadTodos 全量刷新
  - 几乎所有操作（toggleStatus、updateText、reorder 等）最终都调用 `loadTodos()` 全量重新加载
  - 随 Todo 数量增长，这会导致不必要的数据库查询和 UI 重建
  - **建议**：改为局部更新（在内存中修改列表，仅必要时全量刷新）。
  - **已处理**：在 `TodoListNotifier` 中实现了局部更新逻辑，对于文本、优先级、分类、截止时间等单数据点更新使用内存中的局部状态替换，仅在失败时回退到全量刷新，显著减少了不必要的数据库查询。

### 24. tagsForTodoProvider 逐 Todo 请求
  - 每个 TodoItemCard 都通过 `tagsForTodoProvider(todo.id)` 独立查询标签
  - 在列表视图下，N 个 Todo 产生 N 次数据库查询
  - **建议**：批量预加载标签数据，或在 loadTodos 时一并获取所有关联标签。
  - **已处理**：实现了 `todoTagsCacheNotifierProvider` 批量加载机制，在 `loadTodos()` 中批量加载所有 Todo 的标签，减少了 N 次独立查询的开销。

### 25. getAvailableStorage 硬编码返回值
  - `ModelManagerService.getAvailableStorage()` 硬编码返回 `1073741824`（1GB）
  - **问题**：无法反映真实存储状态，可能导致下载模型时空间不足
  - **建议**：使用平台 API 获取实际可用存储空间。
  - **已处理**：实现了 `getFreeBytes()` 方法，通过 `com.audionotes/storage` 平台通道获取真实可用存储空间，同时提供了 Android 和 iOS 的平台特定实现。

---

## 七、潜在运行时错误

### 26. ASRPlatformService 事件流未关闭
- `ASRPlatformService._eventController` 是 broadcast StreamController
- `dispose()` 方法存在但从未被调用
- **问题**：如果 ASRPlatformService 实例被替换，旧的 StreamController 不会被关闭
- **建议**：在 Provider 的 onDispose 中调用 dispose()。

### 27. 录音取消后的占位 Todo 清理
- `RecordingNotifier` 中 `_replacementTodoId` 和 `_replacementOldAudioPath` 已在 `stop()` 中清空
- 当前 Dart 侧没有独立的 `cancelRecording()` 主流程入口
- **问题**：这条以前的风险现在不再像主路径那样直接成立，但如果以后重新接入取消分支，仍需要同步清理这些字段。

---
