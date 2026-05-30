# 允许快速文本输入待办：在现有代码架构下的最小改动实现方案

> 目标：在 **待办设置** 中新增一个开关 `允许快速文本输入待办`。  
> 开启后，主界面右下角原本的录音 FAB 变成 `🖊 快速待办`：
> 
> - **单击**：弹出文本输入框，创建一个“纯文本待办”；
> - **长按**：进入和平时一样的录音模式；
> - 纯文本待办**复用现有语音待办的数据结构**，但 `rawTranscript` 为空；
> - 新建后仍然走现有的列表刷新、分组、同步、提醒、局部刷新链路。

---

## 1. 先看当前代码里已经有什么

你的项目目前已经具备了非常适合做这件事的基础：

### 1.1 `TodoItem` 已经支持 `rawTranscript`

`lib/models/todo_item.dart` 里已经有：

- `text`
- `rawTranscript`
- `audioPath`
- `taskState`
- `status`
- `priority`
- `createdAt`
- `orderIndex`

所以“纯文本待办”完全可以复用这个结构，不需要再建一套新模型。

### 1.2 `TodoRepository` 已有“插入待办”的能力

`lib/data/todo_repository.dart` 里已经有：

- `insertRecognizing(...)`
- `updateToRecognizing(...)`
- `completeRecognition(...)`
- `markFailed(...)`
- `updateText(...)`
- `toggleStatus(...)`

这说明你只需要再补一个“文本待办插入方法”，而不是重写整个 repository。

### 1.3 `RecordingNotifier` 已经管住了录音流程

`lib/providers/app_providers.dart` 里，`RecordingNotifier` 已经负责：

- `start()`
- `stop()`
- `startReRecord()`
- 录音后插入 `recognizing` todo
- 后台识别完成后刷新列表

所以你的新功能应当尽量**复用这个录音入口**，不要拆掉它。

### 1.4 主界面 FAB 已经是一个独立组件

`lib/screens/home_screen.dart` 里的 `_RecordingFAB` 已经独立成一个 widget，并且它已经处理了：

- `recordingState`
- `isModelReady`
- 点击缩放反馈
- 录音开始 / 停止
- 模型未准备好时引导下载

这非常适合在这里做“按开关切换为文本入口”。

---

## 2. 这次新增功能的行为定义

### 开关名

建议在“待办设置”里新增：

- `允许快速文本输入待办`

### 开关关闭时

保持现状：

- 主界面右下角显示录音 FAB
- 单击开始录音
- 再单击停止录音
- 录音后生成语音待办

### 开关开启时

主界面右下角变成：

- `🖊 快速待办`
- **单击**：弹出文本输入对话框
- **长按**：仍然进入录音模式
- 文本输入确认后，立即创建一个待办

### 文本待办的数据要求

新建的文本待办：

- 仍然是 `TodoItem`
- `rawTranscript = ''`（空字符串）
- `audioPath = null`
- `taskState = TodoTaskState.ready`
- `status = TodoStatus.pending`
- `priority = settings.defaultTodoPriority`
- `text = 用户输入内容`

这样做的好处是：

1. 继续复用现有 todo 列表、排序、分组、同步和提醒逻辑；
2. `rawTranscript` 为空即可在业务语义上区分“纯文本待办”和“语音转写待办”；
3. 不需要引入第二套任务模型。

---

## 3. 最小改动的整体方案

建议只动四层：

1. **设置层**：增加一个开关配置；
2. **数据层**：增加一个文本待办插入方法；
3. **主界面层**：根据开关切换 FAB 交互；
4. **交互层**：补一个输入对话框。

---

## 4. 设置层改造

---

### 4.1 修改 `SettingsState`

文件：

- `lib/models/settings_state.dart`

新增字段：

```dart
final bool enableQuickTextTodo;
```

建议默认值：

```dart
this.enableQuickTextTodo = false,
```

在 `initial()` 里也加上默认值：

```dart
enableQuickTextTodo: false,
```

在 `copyWith()` 里补上：

```dart
bool? enableQuickTextTodo,
```

并在返回对象时写入：

```dart
enableQuickTextTodo: enableQuickTextTodo ?? this.enableQuickTextTodo,
```

---

### 4.2 修改 `SettingsRepository`

文件：

- `lib/repositories/settings_repository.dart`

新增 SharedPreferences key：

```dart
static const String _enableQuickTextTodoKey = 'enable_quick_text_todo';
```

在 `loadSettings()` 中读取：

```dart
enableQuickTextTodo: prefs.getBool(_enableQuickTextTodoKey) ?? false,
```

在 `saveSettings()` 中写入：

```dart
result = result &&
    await prefs.setBool(
      _enableQuickTextTodoKey,
      settings.enableQuickTextTodo,
    );
```

---

### 4.3 修改 `SettingsNotifier`

文件：

- `lib/providers/settings_provider.dart`

新增方法：

```dart
Future<void> setEnableQuickTextTodo(bool enabled) async {
  state = state.copyWith(enableQuickTextTodo: enabled);
  await _saveSettings();
}
```

---

### 4.4 修改“待办设置”页

文件：

- `lib/screens/settings/todo_settings_screen.dart`

在现有“默认优先级 / 已完成聚合 / 垃圾桶保留期”之中，加入一个新的 `SwitchListTile`：

```dart
_SectionCard(
  title: context.tr('settings.todo.quickTextTodo'),
  child: SwitchListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(context.tr('settings.todo.quickTextTodoTitle')),
    subtitle: Text(
      context.tr('settings.todo.quickTextTodoSubtitle'),
      style: theme.textTheme.bodySmall,
    ),
    value: settings.enableQuickTextTodo,
    onChanged: (value) {
      ref.read(settingsProvider.notifier).setEnableQuickTextTodo(value);
    },
  ),
),
```

---

## 5. 数据层改造：新增“纯文本待办”插入方法

---

### 5.1 新增 repository 方法

文件：

- `lib/data/todo_repository.dart`

建议新增一个专门方法，避免把语音逻辑和文本逻辑混在一起：

```dart
Future<TodoItem> insertTextTodo({
  required String text,
  TodoPriority priority = TodoPriority.normal,
}) async {
  final normalizedText = text.trim();
  if (normalizedText.isEmpty) {
    throw ArgumentError('text must not be empty');
  }

  final orderIndex = await _dbHelper.getNextOrderIndex();

  final todo = TodoItem(
    id: _uuid.v4(),
    text: normalizedText,
    rawTranscript: '',
    createdAt: DateTime.now(),
    audioPath: null,
    taskState: TodoTaskState.ready,
    status: TodoStatus.pending,
    priority: priority,
    orderIndex: orderIndex,
  );

  return await _dbHelper.insertTodo(todo);
}
```

---

### 5.2 为什么建议 `rawTranscript = ''`

这样可以明确区分：

- **语音待办**：`rawTranscript` 有值，说明来自语音转写；
- **纯文本待办**：`rawTranscript` 为空，说明是手动输入。

这不会影响列表显示，因为主文案仍然用 `text`。

---

### 5.3 是否需要新增 use case

不是必须。

如果你想保持和“语音流程”一样有清晰的业务层，也可以新增：

- `lib/domain/usecases/create_todo_from_text_usecase.dart`

但从“最小改动”角度看，建议先直接在 `TodoRepository` 上补方法，然后由 `TodoListNotifier` 或 `_RecordingFAB` 调用即可。

---

## 6. 主界面 FAB 改造

---

### 6.1 当前 FAB 的现状

当前 `lib/screens/home_screen.dart` 里的 `_RecordingFAB` 已经做了：

- 缩放动画
- 点击反馈
- 录音状态切换
- 录音开始 / 停止
- 模型准备判断

所以最适合的做法是：**在这个 widget 内部切换模式**，而不是新建一个完全独立的入口。

---

### 6.2 新交互规则

#### 当 `enableQuickTextTodo == false`

保持原逻辑不变：

- `onPressed`：开始 / 停止录音
- 图标：麦克风 / 停止
- 文案：start / stop / processing

#### 当 `enableQuickTextTodo == true`

变成：

- `onPressed`：弹出文本输入框，快速创建待办
- `onLongPress`：进入原来的录音模式
- 图标：`Icons.edit` 或 `Icons.create_outlined`
- 文案：`🖊 快速待办`

---

### 6.3 推荐 UI 结构

建议把 `_RecordingFAB` 改成“逻辑分层”：

- 先读取 `settings.enableQuickTextTodo`
- 决定当前是“录音模式”还是“文本模式”
- 再分别绑定 `onPressed` 和 `onLongPress`

---

### 6.4 推荐代码结构

#### 伪代码结构

```dart
@override
Widget build(BuildContext context) {
  final recordingState = ref.watch(recordingStateProvider);
  final settings = ref.watch(settingsProvider);
  final quickTextMode = settings.enableQuickTextTodo;

  final fab = FloatingActionButton.extended(
    onPressed: quickTextMode
        ? () => _openQuickTextDialog(context)
        : _getOnPressed(recordingState, ref, context),
    onLongPress: quickTextMode
        ? () => _startRecordingFromLongPress(ref, context)
        : null,
    label: Text(
      quickTextMode
          ? '🖊 快速待办'
          : _labelForRecordingState(recordingState, context),
    ),
    icon: Icon(
      quickTextMode
          ? Icons.edit_outlined
          : (recordingState == RecordingState.idle ? Icons.mic : Icons.stop),
    ),
  );

  return GestureDetector(
    onTapDown: _onTapDown,
    onTapUp: _onTapUp,
    onTapCancel: _onTapCancel,
    onLongPress: quickTextMode ? () => _startRecordingFromLongPress(ref, context) : null,
    child: ...
  );
}
```

---

### 6.5 注意：`FloatingActionButton.extended` 的长按处理

`FloatingActionButton` 本身并不总是直接暴露 `onLongPress` 作为显式参数。  
所以更稳妥的方式是：

- 外层包一层 `GestureDetector`
- `onTap` 触发快速文本输入
- `onLongPress` 触发录音
- 内部的 FAB 只负责视觉和 `onPressed` 状态

例如：

```dart
return GestureDetector(
  onTapDown: _onTapDown,
  onTapUp: _onTapUp,
  onTapCancel: _onTapCancel,
  onTap: quickTextMode ? () => _openQuickTextDialog(context) : null,
  onLongPress: quickTextMode ? () => _startRecordingFromLongPress(ref, context) : null,
  child: AnimatedBuilder(
    animation: _scaleAnimation,
    builder: (context, child) {
      return Transform.scale(
        scale: _scaleAnimation.value,
        child: child,
      );
    },
    child: fab,
  ),
);
```

如果你希望“单击文本输入”和“长按录音”都稳定触发，`GestureDetector` 的手势竞争要测试一下；如有冲突，可以改成：

- `InkWell` 处理点击
- `GestureDetector` 只处理长按
- 或者用 `Listener`/`RawGestureDetector` 精细分配

---

## 7. 快速文本输入对话框

---

### 7.1 对话框目标

点击 `🖊 快速待办` 后弹出一个简洁文本输入框：

- 只输入一行或多行文本
- 提交即创建待办
- 关闭后回到主界面
- 不要求分类、不要求时间、不要求标签

---

### 7.2 建议 UI

一个最轻量的 `showDialog` 或 `showModalBottomSheet` 即可。  
建议优先 `showModalBottomSheet`，因为它更接近“快速输入”的感觉。

#### 推荐布局

- 标题：`快速待办`
- 输入框：支持自动展开到 3～5 行
- 按钮：`取消` / `创建`
- 可选：创建按钮旁显示默认优先级，便于用户理解

---

### 7.3 推荐实现代码

```dart
Future<void> _openQuickTextDialog(BuildContext context) async {
  final controller = TextEditingController();
  final formKey = GlobalKey<FormState>();

  final text = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '快速待办',
                style: Theme.of(ctx).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: controller,
                autofocus: true,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  hintText: '输入待办内容…',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入内容';
                  }
                  return null;
                },
                onFieldSubmitted: (_) {
                  if (formKey.currentState?.validate() ?? false) {
                    Navigator.of(ctx).pop(controller.text);
                  }
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('取消'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      if (formKey.currentState?.validate() ?? false) {
                        Navigator.of(ctx).pop(controller.text);
                      }
                    },
                    child: const Text('创建'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );

  if (text == null) return;

  final trimmed = text.trim();
  if (trimmed.isEmpty) return;

  await _createQuickTextTodo(context, trimmed);
}
```

---

### 7.4 创建文本待办的方法

建议在 `_RecordingFABState` 里再补一个方法：

```dart
Future<void> _createQuickTextTodo(BuildContext context, String text) async {
  try {
    final settings = ref.read(settingsProvider);
    final repository = ref.read(todoRepositoryProvider);

    await repository.insertTextTodo(
      text: text,
      priority: settings.defaultTodoPriority,
    );

    // 刷新列表
    await ref.read(todoListProvider.notifier).loadTodos();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已创建快速待办')),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('创建失败：$e')),
      );
    }
  }
}
```

---

## 8. 长按进入录音模式如何复用原有逻辑

---

### 8.1 最稳的做法

长按时不要重新写一套录音逻辑，直接复用现有的：

- `RecordingNotifier.start()`
- `RecordingNotifier.stop()`

也就是说，快速文本模式只是“入口变了”，录音业务本身不要变。

---

### 8.2 推荐长按方法

```dart
void _startRecordingFromLongPress(WidgetRef ref, BuildContext context) {
  final recordingState = ref.read(recordingStateProvider);
  if (recordingState != RecordingState.idle) return;

  final settings = ref.read(settingsProvider);
  if (!settings.enableQuickTextTodo) return;

  _startRecording(ref.read(recordingStateProvider.notifier), context);
}
```

如果你希望长按在**文本模式**和**录音模式**都始终可用，那就只在开关开启时走文本入口，长按仍然录音即可。

---

## 9. 业务层建议：是否需要新增独立 use case

### 推荐方案：先不新增

最小改动下，先直接用：

- `TodoRepository.insertTextTodo(...)`

由 `_RecordingFAB` 触发即可。

### 如果你想更规范

可以补一个：

- `lib/domain/usecases/create_todo_from_text_usecase.dart`

结构会更清晰：

```dart
class CreateTodoFromTextUseCase {
  final TodoRepository repository;
  final SettingsRepository settingsRepository;

  CreateTodoFromTextUseCase({
    required this.repository,
    required this.settingsRepository,
  });

  Future<TodoItem> execute(String text) async {
    final settings = await settingsRepository.loadSettings();
    return repository.insertTextTodo(
      text: text,
      priority: settings.defaultTodoPriority,
    );
  }
}
```

然后再在 provider 中注入它。  
但这不是必须，属于“更干净但更多改动”的方案。

---

## 10. 对现有列表与同步链路的影响

这个功能最好的地方是：**它对现有列表链路几乎没有破坏性**。

因为你创建的仍然是 `TodoItem`，所以它会自动进入：

- `TodoListNotifier.loadTodos()`
- 分组逻辑
- 排序逻辑
- 完成状态逻辑
- 回收站逻辑
- widget 同步逻辑

### 关键点

只要你在文本待办创建后触发一次 `loadTodos()`，现有的：

- 组内刷新
- 工具条统计
- tag 计数
- widget summary

都能继续工作。

---

## 11. 推荐的最小实现顺序

### 第一步：加设置开关

改：

- `SettingsState`
- `SettingsRepository`
- `SettingsNotifier`
- `TodoSettingsScreen`

### 第二步：加 repository 新方法

改：

- `TodoRepository.insertTextTodo(...)`

### 第三步：改 FAB 逻辑

改：

- `HomeScreen._RecordingFAB`

让它在开关开启时：

- 单击弹文本框
- 长按录音

### 第四步：接入文本创建对话框

补：

- `_openQuickTextDialog()`
- `_createQuickTextTodo()`

### 第五步：测试刷新链路

确认：

- 新增文本待办后列表立即刷新
- 语音录入仍然可用
- 原有录音流程不受影响
- `rawTranscript` 为空的记录在数据库中正常保存

---

## 12. 风险点与处理建议

### 风险 1：单击和长按手势互相干扰

处理：

- 保持按钮区域足够大
- 先测试 `GestureDetector`
- 如果有冲突，再把点击与长按拆到不同层

### 风险 2：文本待办和语音待办看不出区别

处理：

- 不在主列表强调差异
- 只在内部数据上用 `rawTranscript` 为空来区分
- 如需标识，可在详情页里显示“手动输入”来源

### 风险 3：创建后没有刷新

处理：

- 创建后立即 `loadTodos()`
- 若你后面进一步优化局部刷新，再改成局部 patch

### 风险 4：录音模式切回去后 FAB 状态混乱

处理：

- 录音状态仍完全由 `RecordingNotifier` 管理
- 文本模式只改变入口，不改变录音状态机

---

## 13. 验收标准

实现完成后，应满足：

1. 在“待办设置”中可开启/关闭 `允许快速文本输入待办`。
2. 开启后主界面右下角显示 `🖊 快速待办`。
3. 单击它弹出文本输入框。
4. 输入并确认后，生成一个 `rawTranscript = ''` 的待办。
5. 长按它仍然能进入原来的录音流程。
6. 原有语音待办流程不受影响。
7. 新建后列表、统计、widget 同步都正常刷新。

---

## 14. 一句话总结

这次改造的核心不是“新增一种 Todo 类型”，而是**在不破坏现有语音待办模型的前提下，把主入口从单一录音扩展成“文本快速创建 + 长按录音”的双模式入口**。  
只要坚持复用 `TodoItem`、复用 `TodoRepository`、复用 `RecordingNotifier`，这个功能就能做到非常稳，而且改动范围很小。
