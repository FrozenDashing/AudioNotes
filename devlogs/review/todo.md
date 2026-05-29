# AudioNotes 已完成与待完成目标

> 基于 v1.6.6 代码库审查，对照 `goal.md` 中定义的功能目标进行逐项评估。

---

## ✅ 已完成

### 核心功能

| # | 功能 | 状态 | 说明 |
|---|------|------|------|
| 1 | 离线语音识别（Vosk ASR） | ✅ 完成 | 通过原生平台通道集成 Vosk，支持离线识别 |
| 2 | 录音与音频管理 | ✅ 完成 | RecorderService + RecognitionService 解耦设计，WAV 格式录制与存储 |
| 3 | 识别中占位状态 | ✅ 完成 | TodoTaskState 枚举（recording/recognizing/ready/failed），UI 展示加载占位 |
| 4 | 语音活动检测（VAD） | ✅ 完成 | 原生层实现 VAD，Dart 端可配置参数（shortPauseMs/longPauseMs/energyThreshold） |
| 5 | 长音频分片识别 | ✅ 完成 | AudioChunker 自动切分超过 60s 的音频 |
| 6 | 置信度评分 | ✅ 完成 | 多维度启发式评分（ASR 置信度 + 文本启发 + 音频质量），存入数据库 |
| 7 | 重新录制（Re-record） | ✅ 完成 | RecordingNotifier.startReRecord() 支持替换已有 Todo 的音频与文本 |
| 8 | 实时部分转录显示 | ✅ 完成 | RecordingOverlay + partialTranscriptProvider |
| 9 | 孤立音频文件清理 | ✅ 完成 | AudioFileCleanup 工具类 |

### 待办事项管理

| # | 功能 | 状态 | 说明 |
|---|------|------|------|
| 10 | Todo CRUD | ✅ 完成 | DatabaseHelper + TodoRepository 完整实现 |
| 11 | 完成/取消完成 | ✅ 完成 | toggleStatus + setStatus + CompletedText 删除线 UI |
| 12 | 软删除 | ✅ 完成 | deletedAt 字段，数据库保留记录 |
| 13 | 拖拽排序 | ✅ 完成 | orderIndex + TodoDragData + 拖拽交互 |
| 14 | 批量操作 | ✅ 完成 | FloatingActionToolbar + 多选模式 + 批量完成/删除 |
| 15 | 优先级体系 | ✅ 完成 | TodoPriority（low/normal/high），新建时支持默认优先级 |
| 16 | 截止日期 | ✅ 完成 | dueAt 字段，UI 设置与展示 |

### 组织与分类

| # | 功能 | 状态 | 说明 |
|---|------|------|------|
| 17 | 分类分组视图 | ✅ 完成 | TodoGroupingService + TodoGroupSection 组件 |
| 18 | 分类折叠/展开 | ✅ 完成 | expandedMap 持久化 |
| 19 | 分类拖拽排序 | ✅ 完成 | groupOrderMap 持久化 |
| 20 | "未分类"组 | ✅ 完成 | uncategorizedGroupKey 常量 |
| 21 | 已完成聚合组 | ✅ 完成 | aggregateCompletedTodos 设置项 + completedGroupKey |
| 22 | 分类管理 | ✅ 完成 | CategoryRepository + CategoryCreateScreen + CategoryPickerScreen |
| 23 | 标签系统 | ✅ 完成 | TagRepository + TagCreateScreen + TagPickerScreen + todo_tags 联表 |
| 24 | 排序系统 | ✅ 完成 | TodoSortField/SortDirection + TodoQueryOptions + 排序底部弹窗 |

### 提醒与通知

| # | 功能 | 状态 | 说明 |
|---|------|------|------|
| 25 | 本地提醒 | ✅ 完成 | ReminderService + NotificationService + flutter_local_notifications |
| 26 | 重复提醒 | ✅ 完成 | TodoRepeatType（daily/weekly），平台通知 matchDateTimeComponents |
| 27 | 启动同步提醒 | ✅ 完成 | main.dart 初始化时调用 syncPendingReminders |
| 28 | Android 精确闹钟适配 | ✅ 完成 | canScheduleExactAlarms + 降级到 inexact 模式 |

### 个性化与设置

| # | 功能 | 状态 | 说明 |
|---|------|------|------|
| 29 | 主题切换 | ✅ 完成 | 浅色/深色/跟随系统/自定义颜色 |
| 30 | 自定义主色调 | ✅ 完成 | customThemeColor + ThemeColorPicker |
| 31 | 字体大小调节 | ✅ 完成 | FontSizeOption + FontSizeSlider + 跟随系统选项 |
| 32 | 设置持久化 | ✅ 完成 | SettingsRepository + SharedPreferences |
| 33 | 国际化（i18n） | ✅ 完成 | flutter_i18n + en.json / zh_CN.json |
| 34 | 模型管理 | ✅ 完成 | ModelManagerService + ModelSelectionScreen，支持下载/删除/重载模型 |

### 数据与架构

| # | 功能 | 状态 | 说明 |
|---|------|------|------|
| 35 | SQLite 数据库 | ✅ 完成 | 5 张表 + 8 个索引，版本迁移至 v5 |
| 36 | 数据库迁移 | ✅ 完成 | _upgradeDB 逐版本增量迁移 |
| 37 | Clean Architecture | ✅ 完成 | data / domain / services / providers / screens / widgets 分层 |
| 38 | Riverpod 状态管理 | ✅ 完成 | 全局 providers，AsyncNotifier/Notifier 模式 |
| 39 | 原生平台通道 | ✅ 完成 | ASR/Recorder/Recognition 三个 MethodChannel |

---

## 🚧 部分完成 / 需完善

| # | 功能 | 状态 | 说明 |
|---|------|------|------|
| 40 | iOS 原生 ASR 插件 | 🚧 部分 | Swift 插件文件存在，但功能完整度待验证（无 Mac 开发环境不易测试） |
| 41 | Web / Desktop 平台 ASR | 🚧 未适配 | UI 层理论支持，但原生 ASR 通道不可用 |
| 42 | 原始转录文本保留 | 🚧 部分 | rawTranscript 字段存在，但当前写入值与 text 相同，未保留 Vosk 原始输出 |
| 43 | 后台排序优化 | 🚧 部分 | sortTodosInBackground 使用 compute，但实际未在主流程中调用 |
| 44 | 重复任务的下次触发 | 🚧 部分 | repeatType 字段存在，通知支持 daily/weekly，但完成后的下次提醒自动创建逻辑缺失 |

---

## ❌ 待完成

| # | 功能 | 优先级 | 说明 |
|---|------|--------|------|
| 45 | 数据导出/备份 | P2 | 无法导出 Todo 数据或音频文件，无备份恢复机制 |
| 46 | 搜索功能 | P1 | 缺少全文搜索，无法快速查找特定 Todo |
| 47 | 统计面板 | P3 | 无完成率、识别准确率等数据统计视图 |
| 48 | 锁屏/后台录音 | P2 | 当前仅支持前台录音，无法在锁屏或后台持续录制 |
| 49 | 多语言 ASR 模型 | P3 | 仅提供中文模型下载，英文等模型未集成 |
| 50 | 数据库加密 | P3 | SQLite 数据库未加密，隐私数据明文存储 |
| 51 | 自动清理策略 | P2 | 软删除数据无自动清理周期，孤立音频清理需手动触发 |
| 52 | Widget 测试覆盖 | P2 | 仅有 todo_item_test.dart 一个模型测试，UI 测试缺失 |
| 53 | 错误上报与日志 | P3 | 无结构化日志或远程错误上报，仅 print 调试 |
| 54 | 无障碍（Accessibility） | P2 | 缺少语义标签、屏幕阅读器适配 |
| 55 | 深色模式自定义色 | P3 | 深色模式下自定义主色调效果未专门优化 |
| 56 | 录音音量可视化 | P3 | 录音时无音量波形或 VAD 状态可视化反馈 |
| 57 | Todo 置顶 | P2 | pinned 字段存在但 UI 未展示置顶效果，排序未优先置顶项 |
| 58 | repeatRule 字段 | P3 | repeatRule 字段存在但无 UI 设置入口，功能未实现 |
| 59 | durationMs 展示 | P3 | 音频时长字段存在但 UI 未展示 |
| 60 | meta 字段 | P3 | meta 字段存在但无使用场景定义 |
