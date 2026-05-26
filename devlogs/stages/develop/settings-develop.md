本文件为 “设置”界面新增三项功能 的功能描述文档，目标将其作为下一阶段开发目标并交付可用实现。三项功能为：切换语音识别模型（Model Switch）、切换主题色（Theme Color）、切换应用字号（Font Size）。文档包含功能清单、UI/交互设计、底层实现细节、数据与存储方案、开发任务与时间表、测试与验收标准、风险与缓解措施，便于工程师直接落地实现。

功能清单（目标行为）
模型切换（Model Switch）

列表展示可用离线模型（名称、大小、精度/速度标签、已下载/未下载状态）。

支持下载、删除、切换当前模型；切换后用于后续离线识别。

支持“自动选择（推荐）”与“手动选择”两种模式。

显示模型占用磁盘与内存预估；提供“轻量模式/高精度模式”切换。

主题色切换（Theme Color）

提供若干预设主题色（至少 4 套：默认、蓝、暖橙、深绿）与“跟随系统”选项。

支持自定义主色（色轮或十六进制输入）并即时预览。

主题切换即时生效（无需重启），并持久化到本地偏好。

字号切换（Font Size）

提供三档预设字号：小 / 中 / 大，并支持自定义百分比（80%–140%）。

在设置页提供“预览区”展示当前字号在待办列表中的效果。

字号切换即时生效并持久化；支持无障碍模式检测并提示（若系统开启大字号则建议同步）。

详细设计与实现细节
UI 与交互（页面结构）
设置主页面结构（单页）

Header：标题 “设置” + 返回按钮。

Section A：语音模型

行项：当前模型名称 + 状态标签（已下载/使用中/未下载）。

进入模型详情页：显示模型列表（卡片式），每个卡片包含：模型名；大小；性能标签（低延迟/高精度）；操作按钮（下载 / 删除 / 设为当前）。

操作反馈：下载进度条、取消按钮、下载完成提示、错误提示。

Section B：主题色

预设色块横向滚动选择；“自定义”按钮打开色轮弹窗；“跟随系统”开关。

右侧显示即时预览（顶部栏 + 列表项勾选样式）。

Section C：字号

三个单选按钮（小/中/大） + 自定义滑块（80%–140%） + 预览区。

“恢复默认”按钮。

Footer：保存/重置（多数设置即时生效，仍保留“恢复默认”）。

底层实现（Flutter 层）
状态管理：使用 Riverpod（或 Provider）管理 SettingsState，包含 modelId、theme、fontScale、autoModelSelect 等字段。

持久化：使用 SharedPreferences（或 Hive）保存轻量偏好；模型下载记录与 metadata 存入本地 SQLite（或文件 JSON）。

即时生效：主题与字号通过全局 Theme 与 TextScaleFactor 注入，设置变更触发 notifyListeners()，UI 立即重绘。

预览区：组件读取当前 SettingsState 并渲染示例列表行，供用户即时感知效果。

原生交互（Model 管理）
模型包管理职责（原生层）

下载：通过原生网络模块（Android: WorkManager/DownloadManager；iOS: URLSession background）实现断点续传与后台下载。

存储路径：模型文件存放在应用私有目录 /models/{modelId}/，并记录版本与校验（SHA256）。

加载/卸载：提供原生 API loadModel(modelId)、unloadModel()、deleteModel(modelId)，并通过 Platform Channel 向 Dart 报告状态与错误码。

内存管理：模型加载为单例，切换模型时先 unload 再 load，并在低内存回调中释放模型。

接口示例（MethodChannel JSON）

Dart → Native: {"cmd":"downloadModel","modelId":"small-v1"}

Native → Dart: {"event":"modelDownloadProgress","modelId":"small-v1","progress":45}

Native → Dart: {"event":"modelLoaded","modelId":"small-v1","success":true}

数据与存储方案
Settings 表（SharedPreferences / Hive）

currentModelId (string)

autoModelSelect (bool)

themeMode (enum: system/default/custom)

themeColorHex (string)

fontScale (float)

Model Metadata（SQLite 或 JSON 文件）

modelId, name, sizeBytes, version, downloadedAt, path, sha256, accuracyTag

磁盘与清理策略

提供“清理模型缓存”入口；当设备剩余空间低于阈值（50MB）阻止新模型下载并提示用户清理。