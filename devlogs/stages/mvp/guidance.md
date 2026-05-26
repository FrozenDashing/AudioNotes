# AudioNotes MVP 架构审查与下一步集成方案

## 一、当前模块整体评价

当前这套 Flutter + Riverpod + Platform Channel + Vosk 的结构，已经具备了一个离线语音 Todo App 的基础骨架：

- 有明确的数据层（Database）
- 有状态管理（Riverpod）
- 有平台层抽象（ASRPlatformService）
- 有模型管理（ModelManagerService）
- 有 UI 与 Widget 分层
- 已经考虑到离线模型下载

说明整体方向是对的。

但从“真正可运行的完整程序”角度来看，目前存在一个核心问题：

> 当前代码更像“概念级 Demo 架构”，而不是“真正闭环的移动端离线语音应用”。

目前很多模块逻辑仍然是：

- 假事件
- 假流程
- 缺少真实生命周期
- 缺少原生闭环
- 缺少异步任务协调
- 缺少资源管理
- 缺少错误恢复机制

下面会从：

1. 架构逻辑问题
2. 模块缺陷
3. 性能问题
4. 原生层缺口
5. 数据流问题
6. 生命周期问题
7. 下一步真正应该怎么接

几个方向系统分析。

---

# 二、当前架构的核心逻辑问题

# 1. 当前“录音”和“识别”逻辑实际上仍然耦合

你原本需求是：

> 先录音 → 保存 wav → 再识别

这是正确路线。

但当前代码里：

```dart
startRecording()
stopRecording()
```

仍然被写成：

```dart
Start audio recording and ASR
```

说明：

ASRPlatformService 的设计仍然是“实时流式识别架构”的残留。

例如：

```dart
partialTranscriptStream
finalSegmentStream
vadBoundary
```

这些全部是：

- 流式识别设计
- 边录边识别设计
- 实时 VAD 架构设计

而不是：

> 文件识别架构

这会导致：

- 架构复杂化
- Platform Channel 消息暴增
- 状态同步困难
- CPU 消耗增大
- 原生层难维护

---

# 正确做法

MVP阶段必须简化为：

```text
录音模块
↓
生成 wav 文件
↓
调用 recognize(filePath)
↓
返回完整文本
↓
生成 Todo
```

因此：

以下内容应该移除：

```dart
partialTranscriptStream
finalSegmentStream
vadBoundary
SpeechSegment
```

因为：

你当前不是流式识别。

---

# 三、真正合理的模块拆分

当前模块：

```text
ASRPlatformService
```

实际上承担了：

- 录音
- ASR
- VAD
- Event Stream
- 状态管理

这是错误的。

---

# 正确拆分

应该拆成：

```text
RecorderService
RecognitionService
ModelService
TodoRepository
```

即：

---

## 1. RecorderService

职责：

- 请求麦克风权限
- 开始录音
- 停止录音
- 返回 wav 文件路径

禁止：

- 不负责 ASR
- 不负责 Todo
- 不负责状态

接口：

```dart
Future<String> startRecording()
Future<String> stopRecording()
Future<void> cancelRecording()
```

---

## 2. RecognitionService

职责：

- 加载 Vosk 模型
- 识别 wav 文件
- 返回文本

接口：

```dart
Future<String> recognize(String wavPath)
```

而不是 event stream。

---

## 3. ModelService

职责：

- 下载模型
- 校验模型
- 解压模型
- 检查版本
- 模型切换

当前的 ModelManagerService 基本方向是对的。

但缺少：

- md5 校验
- 断点续传
- 下载取消
- 模型损坏恢复
- 空间检查

---

## 4. TodoRepository

当前 DatabaseHelper 只是 DB 工具。

真正应该有：

```text
TodoRepository
```

负责：

- DB
- 文件关联
- Todo 创建
- Todo 删除
- 音频删除
- 排序

否则未来：

删除 Todo 后：

```text
数据库删了
wav 没删
```

会造成垃圾文件。

---

# 四、当前最大问题：缺少“任务流水线”

你现在代码的问题是：

> 录音完成以后，没有真正的任务协调系统。

当前逻辑：

```dart
stopRecording()
↓
Future.delayed(500ms)
↓
idle
```

这是假的。

真正流程应该是：

```text
录音结束
↓
生成 wav 文件
↓
插入待办（状态：processing）
↓
后台开始识别
↓
识别成功
↓
更新文本
↓
状态改为 pending
```

---

# 正确的数据状态机

Todo 状态应该扩展：

```dart
enum TodoState {
  recording,
  recognizing,
  ready,
  failed,
}
```

而不是：

```dart
pending/completed
```

因为：

业务状态 与 UI状态 混在一起了。

---

# 正确结构

```dart
class TodoItem {
  final TodoTaskState taskState;
  final TodoStatus status;
}
```

区分：

- 任务生命周期
- 完成状态

---

# 五、数据库结构仍然不完整

当前：

```sql
text
created_at
audio_path
status
```

缺少：

---

## 必须新增字段

### 1. recognition_state

```sql
recognition_state INTEGER
```

用于：

- recognizing
- success
- failed

---

### 2. duration_ms

```sql
duration_ms INTEGER
```

用于：

- UI显示
- 长录音限制
- 后续播放器

---

### 3. language

未来多语言识别。

---

### 4. error_message

识别失败原因。

---

### 5. model_version

未来模型升级兼容。

---

# 六、真正缺失的关键：原生层实现

你现在 Dart 层已经不少了。

真正缺的是：

# Android 原生层

目前没有：

```text
AudioRecord 实现
WAV 写入器
VoskRecognizer
线程池
MethodChannel 回调
```

这才是真正的核心。

---

# Android 正确架构

```text
MainActivity
↓
AudioRecorderManager
↓
WavFileWriter
↓
RecognitionManager
↓
VoskRecognizer
```

---

# 1. AudioRecorderManager

职责：

- AudioRecord 生命周期
- PCM buffer
- 写文件
- 采样率控制
- pause/resume

---

# 2. WavFileWriter

职责：

- 写 WAV Header
- PCM 数据流写入
- close 后修复 header

这是很多 Demo 缺失的。

否则生成的 wav 无法识别。

---

# 3. RecognitionManager

职责：

- 加载 Vosk model
- 线程池执行识别
- 管理队列
- 取消任务
- 内存释放

当前完全没有任务队列。

未来连续录音会崩。

---

# 七、你当前最大的性能隐患

# 1. 模型重复加载

当前结构看起来：

```dart
recognizeAudio(filePath)
```

很可能：

每次重新初始化 Vosk。

这是灾难。

因为：

Vosk model 加载非常重。

---

# 正确做法

原生层保持：

```kotlin
singleton Model
```

应用启动后：

```text
load once
reuse forever
```

否则：

每次识别都会：

- 卡顿
- 爆内存
- CPU 峰值高

---

# 2. 当前没有后台线程

识别不能在主线程。

必须：

```kotlin
Executors.newSingleThreadExecutor()
```

否则 Flutter UI 会冻结。

---

# 3. 当前没有任务取消

如果用户：

```text
录音
↓
识别中
↓
关闭页面
```

当前没有取消机制。

会导致：

- orphan thread
- 内存泄漏
- channel crash

---

# 八、Flutter状态管理的问题

# 当前问题

RecordingNotifier：

```dart
idle
recording
processing
```

太简单。

识别是异步后台任务。

应该：

```dart
recording
saving
recognizing
completed
failed
```

---

# 更严重的问题

当前：

```dart
await stopRecording()
```

后直接：

```dart
Future.delayed(500ms)
```

这是伪逻辑。

真正应该：

```dart
stopRecording()
↓
得到 wavPath
↓
创建 processing todo
↓
await recognize()
↓
update todo
```

---

# 九、正确的完整数据流

真正应该：

```text
用户点击录音
↓
RecorderService.start()
↓
原生 AudioRecord 开始
↓
写 wav 文件
↓
用户停止录音
↓
RecorderService.stop()
↓
返回 wavPath
↓
TodoRepository.insert(
  state=recognizing
)
↓
RecognitionService.recognize(wavPath)
↓
Native 调用 Vosk
↓
返回 text
↓
TodoRepository.update()
↓
UI刷新
```

---

# 十、下一步应该如何真正连接模块

下面是最关键部分。

---

# 第一步：彻底拆 ASRPlatformService

当前：

```text
ASRPlatformService
```

需要拆：

```text
RecorderPlatformService
RecognitionPlatformService
```

---

# 第二步：删除流式识别逻辑

删除：

```dart
partialTranscriptStream
finalSegmentStream
VAD
SpeechSegment
```

因为：

你当前 MVP 根本不需要。

---

# 第三步：建立真正的 UseCase 层

新增：

```text
CreateTodoFromRecordingUseCase
```

这是整个 App 的真正核心。

---

# 正确实现

```dart
class CreateTodoFromRecordingUseCase {
  final RecorderService recorder;
  final RecognitionService recognition;
  final TodoRepository repository;

  Future<void> execute() async {
    final wavPath = await recorder.stop();

    final todoId = await repository.insertProcessing(
      wavPath,
    );

    try {
      final text = await recognition.recognize(wavPath);

      await repository.completeRecognition(
        todoId,
        text,
      );
    } catch (e) {
      await repository.markFailed(todoId);
    }
  }
}
```

这才是：

真正完整闭环。

---

# 十一、下一步优先级（非常重要）

# P0（必须立即完成）

## 1. Android Native Recorder

实现：

```text
AudioRecord
WAV Writer
stop/save
```

---

## 2. Android Native Recognizer

实现：

```text
Vosk Recognizer
recognize(file)
```

---

## 3. Flutter 真正的数据流

实现：

```text
录音
↓
生成 processing todo
↓
识别
↓
更新 todo
```

---

# P1（随后完成）

## 4. 后台线程池

避免 UI 卡死。

---

## 5. 模型缓存

避免重复加载。

---

## 6. 音频文件生命周期

删除 Todo 自动删除 wav。

---

# P2（后续增强）

## 7. 音频播放器

回放录音。

---

## 8. 分段识别

长录音拆 chunk。

---

## 9. 流式实时识别

未来再做。

现在不要碰。

---

# 十二、推荐的最终项目结构

```text
lib/
├── core/
│   ├── errors/
│   ├── utils/
│   └── constants/
│
├── data/
│   ├── datasource/
│   ├── repository/
│   └── models/
│
├── domain/
│   ├── entities/
│   ├── repository/
│   └── usecases/
│
├── services/
│   ├── recorder/
│   ├── recognition/
│   └── model/
│
├── presentation/
│   ├── providers/
│   ├── screens/
│   └── widgets/
│
└── native_bridge/
```

---

# 十三、最终建议

你现在已经完成了：

> “概念验证”阶段

下一步真正关键的是：

# 从“功能模块”进入“任务流水线”

也就是：

```text
录音
↓
文件
↓
任务
↓
识别
↓
数据库
↓
UI
```

而不是：

```text
Event Stream
实时 ASR
partial result
VAD
```

因为：

你的 MVP 目标是：

> 稳定、离线、低功耗、可维护

而不是：

> 实时语音助手。

当前最正确路线：

# “录音文件驱动架构”

这是移动端离线 ASR 最稳的方案。

