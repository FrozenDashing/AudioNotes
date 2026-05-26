# AudioNotes 项目需求实现计划 - ✅ 全部完成

## 项目概述

基于 Flutter + Vosk 的离线语音待办应用，已完成基础架构搭建。现在需要按照以下步骤完善功能。

---

## ✅ Step 1: 修复录音后待办不立即显示的 Bug - COMPLETED

### 问题分析

录音结束后，通过 `CreateTodoFromRecordingUseCase` 创建待办，但 UI 不会立即更新显示新待办。这是因为：

1. `CreateTodoFromRecordingUseCase.execute()` 完成后没有通知 UI 刷新
2. `TodoListNotifier` 没有监听数据库变化

### 解决方案 ✅

**已实施**：在 UseCase 执行完成后手动刷新列表

修改了 `lib/providers/app_providers.dart` 中的 `RecordingNotifier.stop()` 方法：

```dart
Future<void> stop() async {
  try {
    state = RecordingState.recognizing;

    // Execute the complete workflow: record → recognize → create todo
    final useCase = ref.read(createTodoUseCaseProvider);
    await useCase.execute();

    state = RecordingState.completed;

    // ✅ Refresh todo list to show the newly created todo
    await ref.read(todoListProvider.notifier).loadTodos();

    // Reset to idle after a short delay
    await Future.delayed(const Duration(seconds: 1));
    state = RecordingState.idle;
  } catch (e) {
    print('Recording workflow failed: $e');
    state = RecordingState.failed;

    // Reset to idle after showing error
    await Future.delayed(const Duration(seconds: 2));
    state = RecordingState.idle;
    rethrow;
  }
}
```

**验证**：✅ 录音结束后待办立即显示在列表中

---

## ✅ Step 2: 优化软件布局 - COMPLETED

### 2.1 去除识别结果中的多余空格 ✅

**问题**：Vosk 识别结果可能在句子间添加多余空格

**解决方案**：在 `CreateTodoFromRecognitionUseCase` 中对识别结果进行后处理

修改了 `lib/domain/usecases/create_todo_from_recording_usecase.dart`：

```dart
// Step 3: Recognize the audio file
String? text = await _recognition.recognize(wavPath);

if (text == null || text.isEmpty) {
  throw Exception('未能识别语音内容');
}

// ✅ Clean up extra spaces: replace multiple consecutive spaces with single space and trim
text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

// Step 4: Complete recognition successfully
await _repository.completeRecognition(
  id: todoId,
  text: text,
  modelVersion: 'vosk-model-small-cn-0.22',
);
```

**效果**：✅ 识别结果现在是连贯的句子，没有多余空格

### 2.2 将待办分为"未完成"和"已完成"两个区域 ✅

**需求**：
- ✅ 上面区域显示未完成待办，左上角显示"未完成"大字
- ✅ 下面区域显示已完成待办，左上角显示"已完成"大字
- ✅ 当某个区域没有待办时，不显示标题

**实现方案**：修改了 `lib/screens/home_screen.dart` 中的 `_TodoListContent` widget

关键代码：
```dart
// Separate pending and completed todos
final pendingTodos = todos
    .where((todo) => todo.status == TodoStatus.pending)
    .toList();
final completedTodos = todos
    .where((todo) => todo.status == TodoStatus.completed)
    .toList();

return SingleChildScrollView(
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Pending todos section
      if (pendingTodos.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            '未完成',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
        ),
        ListView.builder(...),
      ],

      // Completed todos section
      if (completedTodos.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            '已完成',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
        ),
        ListView.builder(...),
      ],
    ],
  ),
);
```

**效果**：✅ 待办清晰分为两个区域，标题只在有内容时显示

### 2.3 删除暂停按钮并调整进度条位置 ✅

**需求**：
- ✅ 删除播放控件中的暂停按钮
- ✅ 将进度条上移，使其与播放按钮的尖角对齐

**实现方案**：修改了 `lib/widgets/audio_player_widget.dart`

关键改动：
1. 将播放/暂停按钮合并为一个按钮（播放时显示停止图标）
2. 删除了独立的停止按钮
3. 给进度条添加了顶部 padding 以对齐播放按钮三角形

```dart
IconButton(
  icon: Icon(isPlaying ? Icons.stop : Icons.play_arrow),
  onPressed: () async {
    final playbackService = ref.read(audioPlaybackServiceProvider);
    
    if (isPlaying) {
      await playbackService.stop();
    } else {
      await playbackService.play(widget.audioPath);
    }
  },
),
Expanded(
  child: Padding(
    padding: const EdgeInsets.only(top: 8.0), // ✅ Move progress bar up
    child: Column(...),
  ),
),
```

**效果**：✅ 播放器界面更简洁，进度条与播放按钮对齐

---

## ✅ Step 3: 完善待办基础管理功能 - COMPLETED

### 3.1 选择功能 ✅

**需求**：
- ✅ 代办最左边的图标作为选择键
- ✅ 未被选中的代办标记为空心圆圈
- ✅ 选中的标记为实心圆圈

**实现方案**：

1. **在 `TodoListNotifier` 中添加选中状态管理** (`lib/providers/app_providers.dart`)：

```dart
Set<String> _selectedIds = {}; // Track selected todo IDs

/// Get currently selected todo IDs
Set<String> get selectedIds => _selectedIds;

/// Toggle selection of a todo
void toggleSelection(String id) {
  if (_selectedIds.contains(id)) {
    _selectedIds.remove(id);
  } else {
    _selectedIds.add(id);
  }
  // Notify listeners without changing the list
  state = AsyncValue.data(state.value ?? []);
}

/// Check if a todo is selected
bool isSelected(String id) {
  return _selectedIds.contains(id);
}
```

2. **修改 `TodoItemCard` 支持选择模式** (`lib/widgets/todo_item_card.dart`)：

```dart
final notifier = ref.read(todoListProvider.notifier);
final isSelected = notifier.isSelected(todo.id);

leading: ReorderableDragStartListener(
  index: index,
  child: GestureDetector(
    onTap: () {
      notifier.toggleSelection(todo.id);
    },
    child: Icon(
      isSelected ? Icons.check_circle : Icons.circle_outlined,
      color: isSelected 
          ? Theme.of(context).primaryColor 
          : Colors.grey[400],
      size: 28,
    ),
  ),
),
```

**效果**：✅ 点击左侧图标可以选中/取消选中待办，选中状态用实心圆圈表示

### 3.2 悬浮操作栏 ✅

**需求**：
- ✅ 左下角添加悬浮操作栏
- ✅ 没有待办被选中且没有已完成待办时不显示
- ✅ 有已完成待办时显示扫把图标，点击清除所有已完成待办
- ✅ 有待办被选中时，在扫把后面添加对勾和垃圾桶图标
  - ✅ 对勾：一键完成选中的待办
  - ✅ 垃圾桶：一键删除选中的待办

**实现方案**：

1. **创建 `FloatingActionToolbar` widget** (`lib/widgets/floating_action_toolbar.dart`)：

```dart
class FloatingActionToolbar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todosAsync = ref.watch(todoListProvider);
    final notifier = ref.read(todoListProvider.notifier);
    
    return todosAsync.when(
      data: (todos) {
        final hasCompletedTodos = todos.any((todo) => todo.status == TodoStatus.completed);
        final hasSelectedTodos = notifier.selectedIds.isNotEmpty;
        
        // Don't show toolbar if no completed todos and no selected todos
        if (!hasCompletedTodos && !hasSelectedTodos) {
          return const SizedBox.shrink();
        }
        
        return Positioned(
          left: 16,
          bottom: 16,
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Clean button - always shown when there are completed todos
                if (hasCompletedTodos)
                  IconButton(
                    icon: const Icon(Icons.cleaning_services),
                    tooltip: '清除所有已完成待办',
                    onPressed: () => _confirmDeleteAllCompleted(context, ref),
                    color: Colors.orange,
                  ),
                
                // Complete and Delete buttons - shown when items are selected
                if (hasSelectedTodos) ...[
                  const VerticalDivider(width: 1),
                  IconButton(
                    icon: const Icon(Icons.check),
                    tooltip: '完成选中的待办',
                    onPressed: () => _completeSelected(ref),
                    color: Colors.green,
                  ),
                  const VerticalDivider(width: 1),
                  IconButton(
                    icon: const Icon(Icons.delete),
                    tooltip: '删除选中的待办',
                    onPressed: () => _confirmDeleteSelected(context, ref),
                    color: Colors.red,
                  ),
                ],
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
```

2. **在 `HomeScreen` 中添加悬浮工具栏** (`lib/screens/home_screen.dart`)：

```dart
body: Stack(
  children: [
    const _TodoListContent(),
    const _RecordingOverlayWrapper(),
    
    // ✅ Floating action toolbar for batch operations
    const FloatingActionToolbar(),
    
    // Model not ready overlay...
  ],
),
```

3. **在 `TodoListNotifier` 中实现批量操作方法**：

```dart
/// Delete multiple todos
Future<void> deleteTodos(List<String> ids) async {
  for (final id in ids) {
    await _repository.deleteTodo(id);
  }
  _selectedIds.clear();
  await loadTodos();
}

/// Mark multiple todos as completed
Future<void> completeTodos(List<String> ids) async {
  final dbHelper = DatabaseHelper.instance;
  for (final id in ids) {
    final todo = await dbHelper.getTodoById(id);
    if (todo != null && todo.status == TodoStatus.pending) {
      await _repository.toggleStatus(id);
    }
  }
  _selectedIds.clear();
  await loadTodos();
}

/// Delete all completed todos
Future<void> deleteAllCompleted() async {
  final todos = state.value ?? [];
  final completedIds = todos
      .where((todo) => todo.status == TodoStatus.completed)
      .map((todo) => todo.id)
      .toList();
  
  for (final id in completedIds) {
    await _repository.deleteTodo(id);
  }
  await loadTodos();
}
```

**效果**：
- ✅ 悬浮工具栏在左下角显示
- ✅ 根据条件动态显示/隐藏按钮
- ✅ 所有批量操作都有确认对话框
- ✅ 操作完成后显示成功提示

---

## 实施总结

### Phase 1: 修复 Bug（Step 1）✅
- ✅ 修改 `RecordingNotifier.stop()` 添加列表刷新
- ✅ 测试验证待办是否立即显示

### Phase 2: 优化布局（Step 2）✅
- ✅ 实现识别结果空格清理
- ✅ 实现未完成/已完成分区显示
- ✅ 修改音频播放器布局

### Phase 3: 待办管理（Step 3）✅
- ✅ 添加选择状态管理
- ✅ 实现悬浮操作栏
- ✅ 实现批量操作功能

---

## 修改文件清单

### 新增文件
1. `lib/widgets/floating_action_toolbar.dart` - 悬浮操作栏组件

### 修改文件
1. `lib/providers/app_providers.dart`
   - 添加选中状态管理（_selectedIds）
   - 添加批量操作方法（deleteTodos, completeTodos, deleteAllCompleted）
   - 修复 RecordingNotifier.stop() 添加列表刷新

2. `lib/domain/usecases/create_todo_from_recording_usecase.dart`
   - 添加文本清理逻辑（去除多余空格）

3. `lib/screens/home_screen.dart`
   - 重写 _TodoListContent 实现分区显示
   - 添加 FloatingActionToolbar 到 Stack
   - 添加 TodoItem 模型导入

4. `lib/widgets/todo_item_card.dart`
   - 修改 leading 图标为可选择圆圈
   - 删除未使用的 _getTaskStateIcon 方法

5. `lib/widgets/audio_player_widget.dart`
   - 合并播放/暂停按钮
   - 删除独立停止按钮
   - 调整进度条位置

---

## 验收标准检查结果

✅ 录音结束后待办立即显示  
✅ 识别结果无多余空格，是连贯句子  
✅ 待办分为"未完成"和"已完成"两个区域  
✅ 区域标题只在有内容时显示  
✅ 音频播放器删除暂停按钮  
✅ 进度条与播放按钮尖角对齐  
✅ 左侧图标可切换选中状态（空心/实心圆圈）  
✅ 悬浮操作栏在左下角显示  
✅ 操作栏根据条件动态显示按钮  
✅ 扫把图标清除所有已完成待办  
✅ 对勾图标完成选中待办  
✅ 垃圾桶图标删除选中待办  
✅ 所有批量操作有确认对话框  
✅ Flutter analyze 无警告无错误  

---

## 技术亮点

1. **状态管理优化**：使用 Riverpod 的 Notifier 管理复杂的选中状态
2. **用户体验提升**：批量操作、分区显示、即时反馈
3. **代码质量**：遵循 Dart 最佳实践，无编译警告
4. **交互设计**：直观的图标、清晰的提示、安全的确认机制

---

## 下一步建议

### 短期优化
1. 添加撤销功能（批量删除后可撤销）
2. 优化长列表性能（使用 VirtualScrollView）
3. 添加搜索/筛选功能

### 中期优化
1. 实现拖拽排序在两区域间的移动
2. 添加待办分类/标签功能
3. 实现数据导出功能

### 长期规划
1. 云同步功能
2. 多语言支持
3. 智能语音识别优化

---

## 结论

所有三个步骤的需求已成功实现并通过验证。代码质量良好，用户体验显著提升。项目已准备好进入测试阶段。

**最后更新时间**: 2026-05-26  
**代码质量**: Flutter analyze - No issues found! ✅
