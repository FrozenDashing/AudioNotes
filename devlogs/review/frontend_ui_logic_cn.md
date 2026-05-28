# AudioNotes 前端 UI 渲染逻辑

## 概述
AudioNotes 应用程序采用基于 Flutter 的架构，使用 Riverpod 进行状态管理。UI 渲染逻辑围绕响应式状态更新构建，这些更新响应应用程序状态的变化。

## 主要应用程序流程

```
main.dart
  ↓
AudioNotesApp (ConsumerStatefulWidget)
  ↓
MaterialApp 带 Riverpod ProviderScope
  ↓
HomeScreen (ConsumerStatefulWidget)
```

## UI 组件层次结构

### 1. 主屏幕结构
```
Scaffold
├── AppBar
│   ├── Leading: 选择模式控制或菜单
│   └── Actions: 设置图标
├── Body: Stack (多层重叠)
│   ├── _TodoListContent (主要待办事项显示)
│   ├── _RecordingOverlayWrapper (录音状态覆盖)
│   ├── FloatingActionToolbar (批量操作)
│   └── 模型下载覆盖 (条件显示)
└── FloatingActionButton: 录音控制
```

### 2. 待办事项列表内容
```
_TodoListContent (ConsumerWidget)
  ↓
FutureBuilder (todoListProvider)
  ├── 加载状态: CircularProgressIndicator
  ├── 错误状态: 错误消息显示
  └── 数据状态: 待办事项显示
      ↓
ReorderableListView (启用手动排序)
  ↓
分组服务 (分类待办事项)
  ↓
TodoGroupSection Widgets (每组)
  ↓
单个 TodoItemCard Widgets (每个待办事项)
```

### 3. 录音流程 UI 组件
```
_RecordingFAB (浮动动作按钮)
  ↓
开始录音 → RecordingState.recording
  ↓
RecordingOverlay (显示实时转录)
  ↓
停止录音 → 处理状态
  ↓
新待办事项添加到列表
```

## 状态驱动的 UI 更新

### 1. 待办事项列表状态管理
- **Provider**: [todoListProvider](lib/providers/app_providers.dart#L774-L777)
- **类型**: AsyncNotifierProvider<List<TodoItem>>
- **更新**: 当项目更改时触发待办事项列表的完整 UI 重建

### 2. 录音状态管理
- **Provider**: [recordingStateProvider](lib/providers/app_providers.dart#L276-L278)
- **类型**: NotifierProvider<RecordingState>
- **状态**: idle | recording | recognizing | completed | failed
- **UI 影响**: 更改浮动按钮外观，显示/隐藏录音覆盖

### 3. 部分转录状态
- **Provider**: [partialTranscriptProvider](lib/providers/app_providers.dart#L289-L291)
- **类型**: NotifierProvider<String>
- **UI 影响**: 在录音期间更新实时转录显示

## UI 交互流程

### 录音过程
1. 用户点击"录音"按钮
2. [recordingStateProvider](lib/providers/app_providers.dart#L276-L278) 变为 RecordingState.recording
3. 浮动按钮图标变为停止图标，颜色变为红色
4. [RecordingOverlay](lib/widgets/recording_overlay.dart#L8-L37) 出现显示实时转录
5. 音频被捕获并由原生插件处理
6. 录音停止时，占位符待办事项出现
7. 后台进行识别
8. 完成后，待办事项文本更新为识别出的文本

### 待办事项管理
1. 用户与 TodoItemCard 交互（切换、编辑、删除）
2. 调用相应的提供者方法 ([todoListProvider](lib/providers/app_providers.dart#L774-L777).notifier)
3. 启动数据库操作
4. 提供者状态更新
5. UI 自动重建反映新状态

## 小部件组合模式

UI 遵循组合模式，将复杂的 UI 元素分解为更小的、专注的小部件：

- **状态依赖小部件**: 仅在其特定状态更改时重建
- **ConsumerWidget**: 有效地仅重建受特定提供者影响的部分
- **关注点分离**: 不同小部件处理不同方面（录音、待办事项显示、覆盖）

## 关键 UI 元素

### TodoItemCard
- 显示单个待办事项
- 处理复选框切换
- 显示完成删除线
- 管理上下文菜单（编辑、删除、重新录音）

### RecordingOverlay
- 在录音期间出现
- 显示实时部分转录
- 指示处理状态

### TodoGroupSection
- 将相关的待办事项组合在一起
- 支持拖放重新排序组内项目
- 可折叠部分

这种架构通过利用 Riverpod 的细粒度重建机制确保了高效的 UI 更新，只有在特定状态发生更改时才会重建必要的 UI 部分。