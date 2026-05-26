# MVP 架构方案
![Copilot](https://img.shields.io/badge/Copilot-Powered-2ea44f?style=flat&logo=githubcopilot)

### 概览
本方案面向 **Flutter + Vosk 离线 ASR** 的 MVP 实现，目标是把参考界面快速落地为可用产品：**一键离线录音 → 流式转写 → 自动按录入时间生成待办条目 → 本地持久化与基本 CRUD**。文档给出可执行的底层架构、平台插件接口、音频流与 VAD 分句策略、数据模型、UI 交互要点、错误与边界处理、测试目标与阶段性里程碑，便于工程师或 AI 自动化工具直接实现。

---

### 底层架构总览
**总体分层**
- **Flutter 层（Dart）**：UI、状态管理、持久化调用、业务逻辑、测试用例。建议使用 **Riverpod** 管理状态。
- **原生插件层（Platform Channel）**：负责音频采集、VAD、Vosk 引擎绑定、文件 I/O、通知。Android 使用 **Kotlin**，iOS 使用 **Swift**。
- **本地存储层**：SQLite（推荐使用 **sqflite**）或轻量级 **Hive** 存储 TodoItem 元数据；音频文件存储在应用沙箱（按日期分目录）。
- **线程与进程模型**：音频采集与 ASR 在原生线程中运行，识别结果通过平台通道异步回调到 Dart。Dart 侧使用 **Isolate** 做后处理与 DB 写入，避免 UI 卡顿。

**关键设计原则**
- **流式处理**：尽量采用流式识别，边说边返回 partial 结果，VAD 触发最终化分句。
- **离线优先**：所有识别与分句在设备本地完成，网络仅用于后续扩展（非 MVP）。
- **顺序一致性**：每个最终化分句生成单条 TodoItem，按 `created_at` 严格排序，支持手动 `order_index` 覆盖。
- **可恢复性**：写 DB 与写音频文件采用事务或原子操作，避免半写入状态。

---

### 关键模块实现细节
#### 1. Flutter 与原生插件接口设计
**消息协议（JSON）**  
- **从 Dart 到原生**：控制命令 `start`, `stop`, `cancel`, `reRecord`, `setVADParams`。  
- **从原生到 Dart**：事件 `partial_transcript`, `final_segment`, `vad_boundary`, `error`, `model_status`。

**示例 Platform Channel 消息格式**
```dart
// Dart -> Native
{
  "cmd": "start",
  "sampleRate": 16000,
  "channels": 1,
  "format": "pcm16"
}

// Native -> Dart partial
{
  "event": "partial_transcript",
  "text": "I need to buy",
  "timestamp": 1620000000
}

// Native -> Dart final segment
{
  "event": "final_segment",
  "text": "I need to buy milk",
  "segment_id": "uuid-1234",
  "start_ts": 1620000000,
  "end_ts": 1620000005,
  "audio_path": "/data/user/0/app/files/audio/2026-05-25/uuid-1234.pcm"
}
```

**插件职责**
- **Android**：使用 `AudioRecord` 以 PCM16 采样，使用 Vosk Android binding 做流式识别，集成 WebRTC VAD 或自实现能量阈值 VAD。识别结果通过 `MethodChannel` 回传。必要时使用前台服务保证长录音稳定。
- **iOS**：使用 `AVAudioEngine` 采集，Vosk iOS binding 或 TFLite 模型推理，使用 `UNUserNotificationCenter` 做本地通知（后续阶段）。

#### 2. 音频采集与缓冲策略
**采样参数**
- **采样率**：16000 Hz（兼顾模型与性能）。  
- **通道**：单声道 PCM16。  
- **帧大小**：每次读取 3200 bytes（对应 100 ms），可调以平衡延迟与 CPU。

**缓冲与流式发送**
- 原生端维护环形缓冲区，按帧送入 Vosk 的流式 API。Dart 侧仅接收识别事件，避免频繁跨通道传输音频数据。

**延迟优化**
- **目标**：首个 partial 在 1.5 秒内出现。  
- **手段**：小帧读取、低延迟音频回调、优先线程调度、避免在主线程做 I/O。

#### 3. VAD 与自动断句策略
**VAD 组合策略**
- **短停顿阈值**：当检测到连续静音 ≥ 600 ms 触发短停顿分句。  
- **长停顿阈值**：静音 ≥ 1500 ms 触发强制分句并保存段落。  
- **能量门限**：结合短时能量与谱熵判断噪声与语音。  
- **后处理**：对 final_segment 做简单规则修正（去除前后停顿、首字母小写修正、常见口语停用词清理）。

**分句容错**
- 若分句过短（< 2 个词），合并到上一个段落或等待更长静音确认。  
- 提供 **置信度指示**（low/medium/high）给 UI，低置信度显示编辑提示。

#### 4. 本地存储与数据模型
**DB 方案**
- 推荐使用 **sqflite**（SQLite）或 **Drift**（更强的类型安全）。若追求极简可用 **Hive**。

**数据表结构（SQLite）**
```sql
CREATE TABLE todo_item (
  id TEXT PRIMARY KEY,
  text TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER,
  audio_path TEXT,
  status INTEGER DEFAULT 0,
  order_index INTEGER,
  confidence REAL,
  meta TEXT
);
CREATE INDEX idx_created_at ON todo_item(created_at);
```

**写入事务**
- 写音频文件成功后写 DB；若 DB 写失败则删除音频文件；若音频写入失败则返回错误并提示用户重试。

#### 5. UI 与交互实现要点
**主界面**
- **ListView**：每行显示 **大字号文本、时间戳、完成勾选、拖拽把手**。  
- **实时流式展示**：录音时顶部或浮层显示 partial 文本，final_segment 立即插入列表顶部或尾部（按设计的时间序列方向）。  
- **编辑入口**：长按或右滑进入编辑/重录。重录调用 `reRecord` 命令并替换对应 `audio_path` 与 `text`。

**悬浮录音**
- **Android**：实现系统悬浮窗，点击唤起小录音面板并开始录音。处理权限与自启动引导。  
- **iOS**：实现 Home Screen Widget 或 Siri Shortcut 触发录音（受系统限制，提供替代方案）。

---

### 错误处理与边界情况
**权限拒绝**
- 显示明确引导页，说明麦克风权限必要性并提供跳转到系统设置的按钮。若用户拒绝，仍允许保存本地未转写的音频文件以便后续授权后转写。

**低存储**
- 在写音频前检查可用空间，低于阈值（例如 50 MB）阻止录音并提示清理。

**高噪声或识别失败**
- 标记该段 `confidence` 低，UI 显示“识别可能有误，点击编辑”。提供一键重录与手动文本输入。

**崩溃与数据一致性**
- 启用崩溃上报（可选），在启动时做 DB 完整性检查，修复或回滚半写入记录。

---

### 测试与性能目标
**功能测试**
- **录音分句**：连续说三句，产生三条 final_segment。  
- **编辑与重录**：重录后文本与音频路径替换并持久化。  
- **排序持久化**：手动拖拽后 `order_index` 保存并在重启后保持。

**性能目标**
- **首个 partial** ≤ 1.5 秒。  
- **最终化分句** 在静音确认后 ≤ 0.5 秒写入 DB。  
- **CPU**：录音识别期间 UI 主线程无卡顿，识别线程 CPU 占用在可接受范围（中端设备 ≤ 30% 单核）。  
- **内存**：ASR 模型加载后内存占用控制在可接受范围（视模型大小，目标 < 200 MB）。

**测试矩阵**
- 设备：低端 Android（2GB RAM）、中端 Android、iPhone 中端机型。  
- 场景：安静室内、街道噪声、车内噪声、多人同时说话。  
- 自动化：生成脚本模拟音频输入并验证 final_segment 事件与 DB 写入。

---

### 开发里程碑与时间估算
**阶段 0 PoC（1 周）**
- 目标：原生端 Vosk 流式识别 + VAD 分句 demo。交付：Android 与 iOS 原生 demo。

**阶段 1 Flutter 插件与流式集成（2 周）**
- 目标：Platform Channel、Dart 事件处理、partial/final 回调。交付：Flutter demo 显示实时转写。

**阶段 2 本地持久化与列表 UX（1.5 周）**
- 目标：DB schema、写入事务、列表展示、拖拽排序。交付：可持久化的待办列表。

**阶段 3 编辑与重录、悬浮入口（1.5 周）**
- 目标：重录替换、编辑 UI、Android 悬浮按钮实现。交付：完整编辑与快速入口。

**阶段 4 调优与内测（1–2 周）**
- 目标：VAD 参数调优、延迟优化、低端机适配、QA 修复。交付：Beta 内测包。

**总计估时**：**7–10 周**。团队建议：1 名 Flutter 开发、1 名原生/ASR 工程师、0.5 名 UX、1 名 QA。

---

### 交付物与验收标准
**交付物**
- Flutter 项目仓库（含 plugin 源码 Android/Kotlin + iOS/Swift）。  
- PoC 原生 demo。  
- MVP APK/IPA 内测包。  
- 技术文档：插件接口说明、VAD 参数说明、DB schema、部署与构建脚本。  
- 自动化测试脚本与性能测试报告。

**验收标准**
- 离线环境下完成从录音到 final_segment 的闭环，且 final_segment 能生成并持久化 TodoItem。  
- UI 在中端设备上无明显卡顿，首个 partial ≤ 1.5 秒。  
- 编辑与重录功能可用，数据在重启后保持一致。  
- 悬浮录音在 Android 上可用并能在锁屏/后台唤起录音（受系统限制）。
