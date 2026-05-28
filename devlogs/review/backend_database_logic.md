# AudioNotes Backend Processing Functions & Database Logic

## 1. Backend Processing Functions Architecture

### 1.1 Audio Recognition Service
```
Audio Recognition Service
│
├─> recognizeDetailed(audioFilePath)
│   ├─> Loads Vosk ASR model
│   ├─> Processes WAV file using Vosk engine
│   ├─> Returns detailed result with confidence score
│   └─> Handles timeout and retry mechanisms
│
├─> isModelReady()
│   └─> Checks if Vosk model is loaded
│
└─> reloadModel()
    └─> Reloads ASR model from storage
```

### 1.2 Recorder Service
```
Recorder Service
│
├─> startRecording()
│   ├─> Initializes audio recording via native plugin
│   ├─> Creates temporary WAV file
│   └─> Returns path to recording file
│
└─> stopRecording()
    └─> Stops audio recording and returns final file path
```

### 1.3 Recognition Notifier (in RecordingNotifier)
```
Recognition Notifier
│
├─> start()
│   ├─> Initiates recording via recorder service
│   └─> Updates state to RecordingState.recording
│
├─> stop()
│   ├─> Stops recording and gets WAV file path
│   ├─> Creates placeholder todo item
│   ├─> Updates state to RecordingState.idle
│   └─> Triggers background recognition process
│
└─> _recognizeRecordingInBackground(todoId, wavPath)
    ├─> Ensures model is ready
    ├─> Performs recognition with retry logic
    ├─> Processes text (normalizes whitespace, adds punctuation)
    ├─> Computes confidence score (text heuristic + audio quality)
    ├─> Completes recognition in database
    └─> Refreshes todo list
```

### 1.4 Todo List Notifier Operations
```
Todo List Notifier
│
├─> loadTodos()
│   └─> Queries database with current query options
│
├─> toggleStatus(id)
│   └─> Updates todo completion status in database
│
├─> updateText(id, newText)
│   └─> Updates todo text in database
│
├─> deleteTodo(id)
│   └─> Removes todo from database
│
├─> reorderTodos(oldIndex, newIndex)
│   └─> Updates order indices in database
│
├─> setQueryOptions(options)
│   └─> Updates query parameters and refreshes list
│
└─> updateReminderTime(id, remindAt)
    └─> Updates reminder time and schedules notification
```

## 2. Database Architecture

### 2.1 Database Schema
```
Database: audionotes.db (SQLite)
Version: 5
Foreign Keys: Enabled

Tables:
├─ todo_item
│   ├─ id: TEXT (Primary Key)
│   ├─ text: TEXT (Processed transcription)
│   ├─ raw_text: TEXT (Raw transcription)
│   ├─ created_at: INTEGER (Timestamp)
│   ├─ updated_at: INTEGER (Timestamp)
│   ├─ audio_path: TEXT (Path to recorded audio)
│   ├─ task_state: INTEGER (Lifecycle state: 0=pending, 1=recognizing, 2=completed, 3=failed)
│   ├─ status: INTEGER (Completion: 0=pending, 1=completed)
│   ├─ priority: INTEGER (Priority level: 0=low, 1=medium, 2=high)
│   ├─ due_at: INTEGER (Due date timestamp)
│   ├─ remind_at: INTEGER (Reminder timestamp)
│   ├─ repeat_type: INTEGER (Repeat pattern)
│   ├─ repeat_rule: TEXT (Repeat rule definition)
│   ├─ category_id: TEXT (Reference to categories table)
│   ├─ pinned: INTEGER (Pin status: 0=unpinned, 1=pinned)
│   ├─ completed_at: INTEGER (Completion timestamp)
│   ├─ deleted_at: INTEGER (Deletion timestamp)
│   ├─ duration_ms: INTEGER (Audio duration)
│   ├─ error_message: TEXT (Error details if recognition failed)
│   ├─ model_version: TEXT (ASR model version used)
│   ├─ order_index: INTEGER (Manual ordering index)
│   ├─ confidence: REAL (Recognition confidence score)
│   └─ meta: TEXT (Additional metadata)
│
├─ categories
│   ├─ id: TEXT (Primary Key)
│   ├─ name: TEXT (Category name)
│   ├─ color: INTEGER (Display color)
│   ├─ sort_order: INTEGER (Sorting order)
│   └─ is_hidden: INTEGER (Visibility: 0=visible, 1=hidden)
│
├─ tags
│   ├─ id: TEXT (Primary Key)
│   ├─ name: TEXT (Tag name)
│   └─ color: INTEGER (Display color)
│
├─ todo_tags
│   ├─ todo_id: TEXT (Foreign Key to todo_item)
│   └─ tag_id: TEXT (Foreign Key to tags)
│
└─ reminders
    ├─ id: TEXT (Primary Key)
    ├─ todo_id: TEXT (Foreign Key to todo_item)
    ├─ notification_id: INTEGER (System notification ID)
    ├─ remind_at: INTEGER (Reminder timestamp)
    └─ fired: INTEGER (Fired status: 0=not fired, 1=fired)
```

### 2.2 Indexes
```
Indexes:
├─ idx_created_at (on todo_item.created_at)
├─ idx_order_index (on todo_item.order_index)
├─ idx_task_state (on todo_item.task_state)
├─ idx_priority (on todo_item.priority)
├─ idx_due_at (on todo_item.due_at)
├─ idx_remind_at (on todo_item.remind_at)
├─ idx_category_id (on todo_item.category_id)
├─ idx_deleted_at (on todo_item.deleted_at)
├─ idx_reminders_todo_id (on reminders.todo_id)
├─ idx_reminders_notification_id (on reminders.notification_id)
└─ idx_reminders_remind_at (on reminders.remind_at)
```

### 2.3 Database Helper Operations
```
Database Helper Instance
│
├─ insertTodo(todo)
│   └─ Inserts or replaces a todo item in the database
│
├─ getTodos(options)
│   └─ Retrieves todos with filtering and sorting options
│
├─ getTodoById(id)
│   └─ Retrieves a single todo by ID
│
├─ updateTodo(todo)
│   └─ Updates a todo item in the database
│
├─ deleteTodo(id)
│   └─ Deletes a todo item by ID
│
├─ updateOrderIndices(orderMap)
│   └─ Batch updates order indices for multiple items
│
├─ toggleStatus(id)
│   └─ Toggles completion status of a todo
│
├─ updateDueAt(id, dueAt)
│   └─ Updates due date for a todo
│
├─ updateRemindAt(id, remindAt)
│   └─ Updates reminder time for a todo
│
├─ updateCategory(id, categoryId)
│   └─ Updates category assignment for a todo
│
├─ updatePriority(id, priority)
│   └─ Updates priority level for a todo
│
├─ upsertReminder(...)
│   └─ Inserts or updates reminder record
│
├─ getRemindersDueBefore(before)
│   └─ Gets reminders due before specified time
│
├─ markReminderFired(notificationId)
│   └─ Marks a reminder as fired
│
├─ insertCategory(category)
│   └─ Inserts or updates a category
│
├─ getCategories()
│   └─ Retrieves all categories
│
├─ insertTag(tag)
│   └─ Inserts or updates a tag
│
├─ getTags()
│   └─ Retrieves all tags
│
├─ setTagsForTodo(todoId, tagIds)
│   └─ Replaces tag associations for a todo
│
└─ close()
    └─ Closes the database connection
```

### 2.4 Database Migration Strategy
```
Migration Path (v1 -> v5):
├─ v1 to v2: Add task lifecycle columns (task_state, duration_ms, error_message, model_version)
├─ v2 to v3: Add advanced features (raw_text, due_at, remind_at, repeat, category, pinning, timestamps)
│            Add supporting tables (categories, tags, todo_tags, reminders)
├─ v3 to v4: Add notification ID to reminders table for system notifications
└─ v4 to v5: Add priority column to todo_item table
```

## 3. API Interaction Flow

### 3.1 Recording to Todo Creation Flow
```
UI Request -> State Provider -> Service -> Database -> UI Update
│
├─ User taps record button
├─ RecordingStateProvider.start() called
├─ RecorderService.startRecording() invoked
├─ Native audio recording initiated
├─ User stops recording
├─ RecordingStateProvider.stop() called
├─ Placeholder todo created in database
├─ Background recognition started
├─ Recognition completed with text
├─ Database updated with recognized text
└─ UI automatically refreshed with new todo
```

### 3.2 Todo Management Flow
```
UI Action -> Provider -> Database -> Result
│
├─ Todo status toggle
├─ TodoListNotifier.toggleStatus(id)
├─ DatabaseHelper.updateTodo() with new status
├─ Success response
└─ UI reflects updated status
```

### 3.3 Query & Filtering Flow
```
Filter Change -> Query Options -> Database Query -> Results
│
├─ Sort option changed
├─ TodoListNotifier.setQueryOptions(options)
├─ DatabaseHelper.getTodos(options) with filters/sort
├─ Results returned
└─ UI updated with sorted/filtered list
```

## 4. Error Handling & Recovery

### 4.1 Recognition Error Handling
- Recognition timeouts with retry mechanism
- Failed recognition marked with error message
- Placeholder remains visible with error indicator
- Manual retry option available

### 4.2 Database Error Handling
- Transaction-based operations for data integrity
- Batch operations for efficiency
- Proper null checks and fallback values
- Foreign key constraints for referential integrity