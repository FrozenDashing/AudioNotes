# AudioNotes - 离线语音转文本待办事项应用

[English Version](./README.md) | 中文版

AudioNotes 是一款离线优先的移动应用，使用 Vosk 自动语音识别（ASR）将语音转换为可操作的待办事项。该应用专为提高生产力而设计，允许用户无需双手操作即可记录想法，并自动生成有组织的待办事项列表，无需互联网连接。应用具有基于类别的分组、高级待办事项管理和全面的组织工具，以最大化效率。

## 🚀 功能特性

### 核心功能
- **离线语音识别**：由 Vosk ASR 引擎驱动，完全离线工作，无需互联网依赖
- **实时转录**：在用户说话时流式传输部分结果，提供即时反馈
- **语音活动检测（VAD）**：根据停顿自动分割句子，实现更好的组织
- **智能待办事项创建**：将口语想法转换为带有时间戳的结构化待办事项
- **音频播放**：每个待办事项包含原始音频录音供参考
- **待办事项管理**：通过直观的界面创建、编辑、重新排序和完成任务
- **可选文本输入**：除了语音识别外，还支持手动文本输入模式，支持富文本格式
- **桌面小组件**：主屏幕小组件可快速访问最近的待办事项和录音功能
- **系统日历同步**：与系统日历完全双向同步，支持冲突解决

### 高级组织功能
- **类别分组**：待办事项组织成可折叠的类别组（包含"未分类"用于未分配类别的项目）
- **灵活标签**：每个待办事项支持多个标签，实现增强分类
- **优先级**：低、中、高优先级分配
- **截止日期管理**：为任务设置截止日期
- **提醒系统**：本地通知确保及时完成任务
- **重复任务**：支持每日和每周重复任务

### 用户体验
- **拖放界面**：直观地重新排序类别和类别内的待办事项
- **可折叠组**：展开/折叠类别部分，实现专注查看
- **批量操作**：多选和批量操作，提高管理效率
- **视觉反馈**：任务状态、优先级和截止日期的清晰指示器
- **响应式设计**：针对各种屏幕尺寸和方向进行优化

### 自定义功能
- **模型管理**：下载、切换和管理多个 ASR 模型，支持不同语言/口音
- **可定制界面**：调整主题颜色、字体大小和 UI 元素以符合个人偏好
- **灵活排序**：按手动、创建日期、截止日期或优先级对类别内的待办事项进行排序
- **个性化设置**：通知偏好、默认优先级和 UI 偏好的全面设置

### 数据与存储
- **持久存储**：所有数据使用 SQLite 本地存储，音频文件安全保存
- **软删除**：待办事项标记为已删除但保留以便恢复
- **置信度跟踪**：识别质量评分，用于准确性评估
- **跨平台支持**：在 Android 和 iOS 设备上无缝运行

## 🛠️ 技术栈

### 前端
- **框架**：[Flutter](https://flutter.dev/)（SDK >= 3.0.0）
- **语言**：[Dart](https://dart.dev/)（SDK >= 3.0.0）
- **状态管理**：[Riverpod](https://riverpod.dev/) 用于响应式状态管理
- **UI 组件**：Material Design 3 与响应式布局
- **UI 架构**：关注点分离的 Clean Architecture

### 后端/原生
- **Android**：[Kotlin](https://kotlinlang.org/)（最低 API 21）
- **iOS**：[Swift](https://developer.apple.com/swift/)（最低 iOS 12.0）
- **ASR 引擎**：[Vosk](https://alphacephei.com/vosk/) 用于离线语音识别
- **平台通道**：MethodChannel 用于 Dart-原生通信

### 数据与存储
- **数据库**：SQLite（通过 [sqflite](https://pub.dev/packages/sqflite) 包）
- **音频格式**：PCM16 用于高质量录音
- **持久化**：SharedPreferences 用于设置和偏好
- **模型存储**：本地文件系统用于 ASR 模型

### 依赖项
- `flutter_riverpod`：状态管理
- `sqflite`：SQLite 数据库访问
- `path_provider`：文件系统路径
- `permission_handler`：运行时权限
- `audioplayers`：音频播放
- `shared_preferences`：设置持久化
- `equatable`：对象比较
- `json_annotation`：JSON 序列化
- `http`：模型下载的网络请求
- `flutter_widget_wrapper`：桌面小组件支持
- `device_calendar_plus`：系统日历集成
- `flutter_text_input`：富文本输入功能
- `widget_launcher`：主屏幕小组件管理

## 🏗️ 架构

AudioNotes 遵循 Clean Architecture 原则，具有三个主要层次，并增加了用于基于类别分组的分组服务：

```
┌─────────────────┐    ┌─────────────────────┐    ┌──────────────────┐
│   Presentation  │───▶│     Domain          │───▶│      Data        │
│   (UI/Widgets)  │    │ (Business Logic)    │    │  (Repositories)  │
│                 │    │                     │    │                  │
│ • Screens       │    │ • Use Cases         │    │ • TodoRepo      │
│ • Widgets       │    │ • Entities          │    │ • ModelRepo     │
│ • Providers     │    │ • Grouping Service  │    │ • Database      │
└─────────────────┘    └─────────────────────┘    └──────────────────┘
```

### 关键组件
- **UI 层**：Flutter 组件和屏幕，使用 Riverpod 状态管理
- **领域层**：业务规则、用例和用于类别组织的分组逻辑
- **数据层**：本地数据库、文件系统和外部服务抽象

## 📱 使用方法

1. **选择输入方式**：在设置中选择语音识别或手动文本输入模式
2. **语音模式**：
   - **开始录音**：点击录音按钮开始说话
   - **自动分段**：应用检测停顿来分离想法
   - **实时转录**：在说话时看到部分结果
   - **待办事项创建**：完成的段落自动成为待办事项
3. **文本模式**：
   - **手动输入**：点击文本输入按钮手动创建待办事项
   - **富文本**：使用粗体、斜体等格式选项
   - **快速添加**：使用快速输入创建简单待办事项
   - **高级选项**：创建时设置优先级、截止日期和类别
4. **组织功能**：
   - **类别组织**：将待办事项分配到类别，或让未分类的项目进入默认组
   - **日历同步**：将重要的待办事项与系统日历同步
   - **小组件访问**：使用主屏幕小组件快速访问最近的待办事项
5. **任务管理**：编辑、完成或播放每个项目的原始音频
6. **自定义设置**：调整主题、字体大小、模型选择、通知偏好和小组件选项

## 🛠️ 开发设置

### 前置要求
- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- Android Studio 或 VS Code（带 Flutter 插件）
- Git

### 安装步骤
```bash
# 1. 克隆仓库
git clone <repository-url>
cd AudioNotes

# 2. 安装依赖
flutter pub get

# 3. 设置 Vosk 模型（下载并放置在 assets/models/）
# 从 https://alphacephei.com/vosk/models 下载模型

# 4. 运行应用
flutter run
```

### 开发命令
```bash
# 运行测试
flutter test

# 分析代码质量
flutter analyze

# 格式化代码
dart format .

# 构建生产版本
flutter build apk --release  # Android
flutter build ios --release  # iOS
```

## 📁 项目结构

项目遵循 Clean Architecture 模式，具有明确的关注点分离，并增加了用于 UI 结构的类别分组服务：

- `lib/` - 主应用代码
  - `data/` - 数据库助手和数据源
  - `domain/` - 业务逻辑和用例
  - `models/` - 数据模型，包括 TodoItem 和 TodoGroup
  - `providers/` - Riverpod 状态提供者
  - `repositories/` - 数据抽象层
  - `screens/` - UI 屏幕
  - `services/` - 业务逻辑服务，包括待办事项分组服务
  - `utils/` - 实用函数
  - `widgets/` - 可重用 UI 组件，包括 TodoGroupSection

## 🤝 贡献

我们欢迎贡献！请查看我们的 [CONTRIBUTING.md](./CONTRIBUTING.md) 了解如何贡献此项目的指南。

## 📄 许可证

此项目根据 MIT 许可证获得许可 - 详情请查看 [LICENSE](./LICENSE) 文件。

## 🙏 致谢

- [Vosk ASR](https://alphacephei.com/vosk/) 提供出色的离线语音识别
- Flutter 团队提供出色的跨平台框架
- 所有帮助改进 AudioNotes 的贡献者