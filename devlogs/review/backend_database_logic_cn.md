# AudioNotes 后端处理函数与数据库逻辑

## 1. 后端处理函数架构

### 1.1 音频识别服务
```
音频识别服务
│
├─> recognizeDetailed(audioFilePath)
│   ├─> 加载 Vosk ASR 模型
│   ├─> 使用 Vosk 引擎处理 WAV 文件
│   ├─> 返回包含置信度的详细结果
│   └─> 处理超时和重试机制
│
├─> isModelReady()
│   └─> 检查 Vosk 模型是否已加载
│
└─> reloadModel()
    └─> 从存储中重新加载 ASR 模型
```

### 1.2 录音服务
```
录音服务
│
├─> startRecording()
│   ├─> 通过原生插件初始化音频录制
│   ├─> 创建临时 WAV 文件
│   └─> 返回录音文件路径
│
└─> stopRecording()
    └─> 停止音频录制并返回最终文件路径
```

### 1.3 识别通知器 (在 RecordingNotifier 中)
```
识别通知器
│
├─> start()
│   ├─> 通过录音服务启动录音
│   └─> 更新状态为 RecordingState.recording
│
├─> stop()
│   ├─> 停止录音并获取 WAV 文件路径
│   ├─> 创建占位符待办事项
│   ├─> 更新状态为 RecordingState.idle
│   └─> 触发后台识别过程
│
└─> _recognizeRecordingInBackground(todoId, wavPath)
    ├─> 确保模型已准备就绪
    ├─> 执行带重试逻辑的识别
    ├─> 处理文本 (标准化空白，添加标点符号)
    ├─> 计算置信度 (文本启发式 + 音频质量)
    ├─> 在数据库中完成识别
    └─> 刷新待办列表
```

### 1.4 待办列表通知器操作
```
待办列表通知器
│
├─> loadTodos()
│   └─> 使用当前查询选项查询数据库
│
├─> toggleStatus(id)
│   └─> 在数据库中更新待办完成状态
│
├─> updateText(id, newText)
│   └─> 在数据库中更新待办文本
│
├─> deleteTodo(id)
│   └─> 从数据库中删除待办
│
├─> reorderTodos(oldIndex, newIndex)
│   └─> 在数据库中更新顺序索引
│
├─> setQueryOptions(options)
│   └─> 更新查询参数并刷新列表
│
└─> updateReminderTime(id, remindAt)
    └─> 更新提醒时间并安排通知
```

## 2. 数据库架构

### 2.1 数据库模式
```
数据库: audionotes.db (SQLite)
版本: 5
外键: 已启用

表:
├─ todo_item
│   ├─ id: TEXT (主键)
│   ├─ text: TEXT (处理过的转录)
│   ├─ raw_text: TEXT (原始转录)
│   ├─ created_at: INTEGER (时间戳)
│   ├─ updated_at: INTEGER (时间戳)
│   ├─ audio_path: TEXT (录制音频的路径)
│   ├─ task_state: INTEGER (生命周期状态: 0=待处理, 1=识别中, 2=已完成, 3=失败)
│   ├─ status: INTEGER (完成状态: 0=待处理, 1=已完成)
│   ├─ priority: INTEGER (优先级: 0=低, 1=中, 2=高)
│   ├─ due_at: INTEGER (截止日期时间戳)
│   ├─ remind_at: INTEGER (提醒时间戳)
│   ├─ repeat_type: INTEGER (重复模式)
│   ├─ repeat_rule: TEXT (重复规则定义)
│   ├─ category_id: TEXT (类别表的引用)
│   ├─ pinned: INTEGER (固定状态: 0=未固定, 1=固定)
│   ├─ completed_at: INTEGER (完成时间戳)
│   ├─ deleted_at: INTEGER (删除时间戳)
│   ├─ duration_ms: INTEGER (音频时长)
│   ├─ error_message: TEXT (识别失败时的错误详情)
│   ├─ model_version: TEXT (使用的 ASR 模型版本)
│   ├─ order_index: INTEGER (手动排序索引)
│   ├─ confidence: REAL (识别置信度分数)
│   └─ meta: TEXT (附加元数据)
│
├─ categories
│   ├─ id: TEXT (主键)
│   ├─ name: TEXT (类别名称)
│   ├─ color: INTEGER (显示颜色)
│   ├─ sort_order: INTEGER (排序顺序)
│   └─ is_hidden: INTEGER (可见性: 0=可见, 1=隐藏)
│
├─ tags
│   ├─ id: TEXT (主键)
│   ├─ name: TEXT (标签名称)
│   └─ color: INTEGER (显示颜色)
│
├─ todo_tags
│   ├─ todo_id: TEXT (对 todo_item 的外键)
│   └─ tag_id: TEXT (对 tags 的外键)
│
└─ reminders
    ├─ id: TEXT (主键)
    ├─ todo_id: TEXT (对 todo_item 的外键)
    ├─ notification_id: INTEGER (系统通知 ID)
    ├─ remind_at: INTEGER (提醒时间戳)
    └─ fired: INTEGER (触发状态: 0=未触发, 1=已触发)
```

### 2.2 索引
```
索引:
├─ idx_created_at (在 todo_item.created_at 上)
├─ idx_order_index (在 todo_item.order_index 上)
├─ idx_task_state (在 todo_item.task_state 上)
├─ idx_priority (在 todo_item.priority 上)
├─ idx_due_at (在 todo_item.due_at 上)
├─ idx_remind_at (在 todo_item.remind_at 上)
├─ idx_category_id (在 todo_item.category_id 上)
├─ idx_deleted_at (在 todo_item.deleted_at 上)
├─ idx_reminders_todo_id (在 reminders.todo_id 上)
├─ idx_reminders_notification_id (在 reminders.notification_id 上)
└─ idx_reminders_remind_at (在 reminders.remind_at 上)
```

### 2.3 数据库助手操作
```
数据库助手实例
│
├─ insertTodo(todo)
│   └─ 在数据库中插入或替换待办事项
│
├─ getTodos(options)
│   └─ 使用过滤和排序选项检索待办事项
│
├─ getTodoById(id)
│   └─ 通过 ID 检索单个待办事项
│
├─ updateTodo(todo)
│   └─ 在数据库中更新待办事项
│
├─ deleteTodo(id)
│   └─ 通过 ID 删除待办事项
│
├─ updateOrderIndices(orderMap)
│   └─ 批量更新多个项目的顺序索引
│
├─ toggleStatus(id)
│   └─ 切换待办事项的完成状态
│
├─ updateDueAt(id, dueAt)
│   └─ 更新待办事项的截止日期
│
├─ updateRemindAt(id, remindAt)
│   └─ 更新待办事项的提醒时间
│
├─ updateCategory(id, categoryId)
│   └─ 更新待办事项的类别分配
│
├─ updatePriority(id, priority)
│   └─ 更新待办事项的优先级
│
├─ upsertReminder(...)
│   └─ 插入或更新提醒记录
│
├─ getRemindersDueBefore(before)
│   └─ 获取指定时间前到期的提醒
│
├─ markReminderFired(notificationId)
│   └─ 标记提醒为已触发
│
├─ insertCategory(category)
│   └─ 插入或更新类别
│
├─ getCategories()
│   └─ 检索所有类别
│
├─ insertTag(tag)
│   └─ 插入或更新标签
│
├─ getTags()
│   └─ 检索所有标签
│
├─ setTagsForTodo(todoId, tagIds)
│   └─ 替换待办事项的标签关联
│
└─ close()
    └─ 关闭数据库连接
```

### 2.4 数据库迁移策略
```
迁移路径 (v1 -> v5):
├─ v1 到 v2: 添加任务生命周期列 (task_state, duration_ms, error_message, model_version)
├─ v2 到 v3: 添加高级功能 (raw_text, due_at, remind_at, repeat, category, pinning, 时间戳)
│            添加支持表 (categories, tags, todo_tags, reminders)
├─ v3 到 v4: 为提醒表添加通知 ID 以支持系统通知
└─ v4 到 v5: 为待办事项表添加优先级列
```

## 3. API 交互流

### 3.1 录音到待办创建流
```
UI 请求 -> 状态提供者 -> 服务 -> 数据库 -> UI 更新
│
├─ 用户点击录音按钮
├─ 调用 RecordingStateProvider.start()
├─ 调用 RecorderService.startRecording()
├─ 启动原生音频录制
├─ 用户停止录音
├─ 调用 RecordingStateProvider.stop()
├─ 在数据库中创建占位符待办
├─ 开始后台识别
├─ 识别完成后获得文本
├─ 数据库使用识别文本更新
└─ UI 自动刷新显示新待办
```

### 3.2 待办管理流
```
UI 操作 -> 提供者 -> 数据库 -> 结果
│
├─ 待办状态切换
├─ 调用 TodoListNotifier.toggleStatus(id)
├─ 调用 DatabaseHelper.updateTodo() 更新新状态
├─ 成功响应
└─ UI 反映更新的状态
```

### 3.3 查询和过滤流
```
筛选更改 -> 查询选项 -> 数据库查询 -> 结果
│
├─ 排序选项更改
├─ 调用 TodoListNotifier.setQueryOptions(options)
├─ 使用过滤器/排序调用 DatabaseHelper.getTodos(options)
├─ 返回结果
└─ UI 更新为排序/过滤后的列表
```

## 4. 错误处理与恢复

### 4.1 识别错误处理
- 识别超时带有重试机制
- 识别失败标记错误消息
- 占位符保持可见并显示错误指示器
- 提供手动重试选项

### 4.2 数据库错误处理
- 事务型操作保证数据完整性
- 批量操作提高效率
- 正确的空值检查和默认值
- 外键约束保证引用完整性