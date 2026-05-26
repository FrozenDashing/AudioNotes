# AudioNotes - Visual System Overview

## 🎯 System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        USER INTERFACE LAYER                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                    HomeScreen                             │  │
│  │  ┌─────────────┐  ┌──────────────┐  ┌────────────────┐  │  │
│  │  │ AppBar      │  │ Todo List    │  │ FAB (Record)   │  │  │
│  │  │ - Title     │  │ - Card 1 ☑️  │  │ - Start/Stop   │  │  │
│  │  │ - Settings  │  │ - Card 2 ☐   │  │ - Dynamic UI   │  │  │
│  │  └─────────────┘  │ - Card 3 ☐   │  └────────────────┘  │  │
│  │                   │ - ...        │                       │  │
│  │                   └──────────────┘                       │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              RecordingOverlay (when active)               │  │
│  │  ┌────────────────────────────────────────────────────┐  │  │
│  │  │  🔴 Recording...                                   │  │  │
│  │  │  "I need to buy milk and..."  ← Partial transcript │  │  │
│  │  └────────────────────────────────────────────────────┘  │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     STATE MANAGEMENT LAYER                       │
│                        (Riverpod Providers)                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────────┐  ┌──────────────────────────────┐    │
│  │ recordingState       │  │ todoListProvider             │    │
│  │ Provider             │  │ StateNotifierProvider        │    │
│  │                      │  │                              │    │
│  │ • idle               │  │ • loadTodos()                │    │
│  │ • recording          │  │ • addFromSegment()           │    │
│  │ • processing         │  │ • toggleStatus()             │    │
│  └──────────────────────┘  │ • updateText()               │    │
│                            │ • deleteTodo()               │    │
│  ┌──────────────────────┐  │ • reorderTodos()             │    │
│  │ partialTranscript    │  └──────────────────────────────┘    │
│  │ StateProvider        │                                      │
│  │                      │  ┌──────────────────────────────┐    │
│  │ Current text being   │  │ databaseHelper               │    │
│  │ recognized           │  │ Provider                     │    │
│  └──────────────────────┘  │                              │    │
│                            │ • insertTodo()               │    │
│  ┌──────────────────────┐  │ • getAllTodos()              │    │
│  │ vadConfig            │  │ • updateTodo()               │    │
│  │ StateNotifier        │  │ • deleteTodo()               │    │
│  │                      │  │ • updateOrderIndices()       │    │
│  │ • shortPauseMs       │  └──────────────────────────────┘    │
│  │ • longPauseMs        │                                      │
│  │ • energyThreshold    │  ┌──────────────────────────────┐    │
│  └──────────────────────┘  │ asrPlatformService           │    │
│                            │ Provider                     │    │
│                            │                              │    │
│                            │ • startRecording()           │    │
│                            │ • stopRecording()            │    │
│                            │ • cancelRecording()          │    │
│                            │ • reRecordSegment()          │    │
│                            │ • setVADConfig()             │    │
│                            └──────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                    PLATFORM CHANNEL LAYER                        │
│                   MethodChannel: "com.audionotes/asr"           │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Dart → Native (Commands)         Native → Dart (Events)       │
│  ┌─────────────────────────┐     ┌──────────────────────────┐  │
│  │ {                       │     │ {                        │  │
│  │   cmd: "start",         │────▶│   event: "partial_       │  │
│  │   sampleRate: 16000,    │     │     transcript",         │  │
│  │   channels: 1,          │     │   text: "...",           │  │
│  │   format: "pcm16"       │     │   timestamp: 123456      │  │
│  │ }                       │◀────│ }                        │  │
│  │                         │     │                          │  │
│  │ { cmd: "stop" }         │────▶│ { event: "final_         │  │
│  │                         │     │     segment",            │  │
│  │ { cmd: "cancel" }       │────▶│   segment_id: "uuid",    │  │
│  │                         │     │   text: "Complete        │  │
│  │ {                       │     │     sentence",           │  │
│  │   cmd: "setVADParams",  │────▶│   audio_path: "/...",    │  │
│  │   short_pause_ms: 600,  │     │   confidence: 0.85       │  │
│  │   long_pause_ms: 1500   │     │ }                        │  │
│  │ }                       │     │                          │  │
│  └─────────────────────────┘     │ { event: "error",        │  │
│                                  │   message: "..."         │  │
│                                  │ }                        │  │
│                                  └──────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┴───────────────┐
              │                               │
              ▼                               ▼
┌─────────────────────────┐   ┌─────────────────────────┐
│    ANDROID NATIVE       │   │      iOS NATIVE         │
│       (Kotlin)          │   │       (Swift)           │
├─────────────────────────┤   ├─────────────────────────┤
│                         │   │                         │
│  AsrPlugin.kt           │   │  AsrPlugin.swift        │
│  ┌───────────────────┐  │   │  ┌───────────────────┐  │
│  │ AudioRecord       │  │   │  │ AVAudioEngine     │  │
│  │ • 16kHz, Mono     │  │   │  │ • 16kHz, Mono     │  │
│  │ • PCM16 format    │  │   │  │ • PCM16 format    │  │
│  └─────────┬─────────┘  │   │  └─────────┬─────────┘  │
│            │            │   │            │            │
│  ┌─────────▼─────────┐  │   │  ┌─────────▼─────────┐  │
│  │ VAD Processing    │  │   │  │ VAD Processing    │  │
│  │ • Energy calc     │  │   │  │ • Energy calc     │  │
│  │ • Silence detect  │  │   │  │ • Silence detect  │  │
│  │ • Segment boundary│  │   │  │ • Segment boundary│  │
│  └─────────┬─────────┘  │   │  └─────────┬─────────┘  │
│            │            │   │            │            │
│  ┌─────────▼─────────┐  │   │  ┌─────────▼─────────┐  │
│  │ Vosk ASR Engine   │  │   │  │ Vosk ASR Engine   │  │
│  │ • Load model      │  │   │  │ • Load model      │  │
│  │ • Stream recogn.  │  │   │  │ • Stream recogn.  │  │
│  │ • Return text     │  │   │  │ • Return text     │  │
│  └─────────┬─────────┘  │   │  └─────────┬─────────┘  │
│            │            │   │            │            │
│  ┌─────────▼─────────┐  │   │  ┌─────────▼─────────┐  │
│  │ File I/O          │  │   │  │ File I/O          │  │
│  │ • Save PCM file   │  │   │  │ • Save PCM file   │  │
│  │ • Organize by date│  │   │  │ • Organize by date│  │
│  └───────────────────┘  │   │  └───────────────────┘  │
│                         │   │                         │
└─────────────────────────┘   └─────────────────────────┘
              │                               │
              └───────────────┬───────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                       STORAGE LAYER                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────────────────────┐  ┌──────────────────────────┐ │
│  │   SQLite Database           │  │   File System             │ │
│  │   (audionotes.db)           │  │                           │ │
│  │                             │  │  /audio/                  │ │
│  │  Table: todo_item           │  │    /2026-05-25/           │ │
│  │  ┌──────────────────────┐   │  │    │  ├─ uuid1.pcm       │ │
│  │  │ id (TEXT, PK)        │   │  │    │  ├─ uuid2.pcm       │ │
│  │  │ text (TEXT)          │   │  │    │  └─ uuid3.pcm       │ │
│  │  │ created_at (INTEGER) │   │  │    /2026-05-26/           │ │
│  │  │ updated_at (INTEGER) │   │  │       └─ ...              │ │
│  │  │ audio_path (TEXT)    │   │  │                           │ │
│  │  │ status (INTEGER)     │   │  │  Format: PCM16            │ │
│  │  │ order_index (INTEGER)│   │  │  Sample Rate: 16000 Hz    │ │
│  │  │ confidence (REAL)    │   │  │  Channels: 1 (Mono)       │ │
│  │  │ meta (TEXT)          │   │  │                           │ │
│  │  └──────────────────────┘   │  └──────────────────────────┘ │
│  │                             │                                 │
│  │  Indexes:                   │                                 │
│  │  • idx_created_at           │                                 │
│  │  • idx_order_index          │                                 │
│  └─────────────────────────────┘                                 │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔄 Data Flow Sequence

### Recording Flow

```
User taps Record button
    │
    ├─> [UI] HomeScreen
    │    └─> FAB onPressed callback
    │
    ├─> [State] recordingStateProvider
    │    └─> state = RecordingState.recording
    │
    ├─> [Service] asrPlatformService.startRecording(config)
    │    │
    │    └─> [Platform Channel] MethodChannel.invokeMethod("start")
    │         │
    │         ├─> [Native Android] AsrPlugin.handleStart()
    │         │    ├─> Check microphone permission
    │         │    ├─> Initialize AudioRecord (16kHz, mono, PCM16)
    │         │    ├─> Start recording thread
    │         │    └─> Begin audio buffer processing
    │         │
    │         └─> [Native iOS] AsrPlugin.handleStart()
    │              ├─> Check microphone permission
    │              ├─> Configure AVAudioEngine
    │              ├─> Install audio tap
    │              └─> Start engine
    │
    └─> [UI] RecordingOverlay appears
         └─> Shows "Recording..." with animated indicator
```

### Speech Recognition Flow

```
Audio frames captured (every 100ms)
    │
    ├─> [Native] Audio buffer received
    │    │
    │    ├─> Calculate energy level
    │    │    └─> RMS of PCM samples
    │    │
    │    ├─> VAD Decision
    │    │    │
    │    │    ├─> IF energy > threshold (speech detected)
    │    │    │    ├─> Reset silence timer
    │    │    │    ├─> Send chunk to Vosk ASR
    │    │    │    │    └─> Get partial transcript
    │    │    │    └─> [Platform Channel] Invoke "onEvent"
    │    │    │         └─> { event: "partial_transcript", text: "..." }
    │    │    │              │
    │    │    │              └─> [Dart] asrPlatformService.eventStream
    │    │    │                   └─> Update partialTranscriptProvider
    │    │    │                        └─> [UI] RecordingOverlay updates text
    │    │    │
    │    │    └─> IF energy < threshold (silence)
    │    │         ├─> Start/increment silence timer
    │    │         │
    │    │         ├─> IF silence >= shortPauseMs (600ms)
    │    │         │    └─> Mark potential segment boundary
    │    │         │
    │    │         └─> IF silence >= longPauseMs (1500ms)
    │    │              └─> FINALIZE SEGMENT
    │    │                   ├─> Generate UUID for segment
    │    │                   ├─> Save audio to file: /audio/YYYY-MM-DD/uuid.pcm
    │    │                   ├─> Create final_segment event
    │    │                   └─> [Platform Channel] Invoke "onEvent"
    │    │                        └─> { 
    │    │                              event: "final_segment",
    │    │                              segment_id: "uuid",
    │    │                              text: "Complete sentence here",
    │    │                              audio_path: "/path/to/file.pcm",
    │    │                              confidence: 0.85
    │    │                            }
    │    │
    │    └─> [Dart] asrPlatformService.finalSegmentStream
    │         └─> Listen in app_providers.dart
    │              └─> todoListNotifier.addFromSegment(segment)
    │                   ├─> Create TodoItem from SpeechSegment
    │                   ├─> [Database] databaseHelper.insertTodo(todo)
    │                   │    └─> SQLite INSERT with transaction
    │                   └─> todoListNotifier.loadTodos()
    │                        └─> [UI] Rebuild ListView with new todo
    │
    └─> User sees new todo card appear in list!
```

### Todo Management Flow

```
User interacts with todo card
    │
    ├─> SCENARIO 1: Toggle Completion
    │    ├─> Tap checkbox
    │    ├─> [State] todoListNotifier.toggleStatus(id)
    │    ├─> [Database] dbHelper.toggleStatus(id)
    │    │    ├─> SELECT todo WHERE id = ?
    │    │    ├─> Flip status (pending ↔ completed)
    │    │    └─> UPDATE todo SET status = ?, updated_at = NOW
    │    ├─> [State] todoListNotifier.loadTodos()
    │    └─> [UI] Card rebuilds with strikethrough
    │
    ├─> SCENARIO 2: Edit Text
    │    ├─> Long press → Select "Edit"
    │    ├─> [UI] Show AlertDialog with TextField
    │    ├─> User modifies text and taps "Save"
    │    ├─> [State] todoListNotifier.updateText(id, newText)
    │    ├─> [Database] dbHelper.updateTodo(updatedTodo)
    │    ├─> [State] todoListNotifier.loadTodos()
    │    └─> [UI] Dialog closes, card shows new text
    │
    ├─> SCENARIO 3: Delete Todo
    │    ├─> Long press → Select "Delete"
    │    ├─> [UI] Show confirmation dialog
    │    ├─> User confirms
    │    ├─> [State] todoListNotifier.deleteTodo(id)
    │    ├─> [Database] dbHelper.deleteTodo(id)
    │    │    └─> DELETE FROM todo_item WHERE id = ?
    │    ├─> [File System] Delete associated audio file
    │    ├─> [State] todoListNotifier.loadTodos()
    │    └─> [UI] Card removed from list with animation
    │
    └─> SCENARIO 4: Reorder Todos
         ├─> Drag card using handle icon
         ├─> Drop at new position
         ├─> [State] todoListNotifier.reorderTodos(oldIndex, newIndex)
         ├─> Reorder list in memory
         ├─> Calculate new order_index for all items
         ├─> [Database] dbHelper.updateOrderIndices(orderMap)
         │    └─> Batch UPDATE with new order_index values
         └─> [UI] List reflects new order
```

---

## 📊 State Management Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    Riverpod Provider Tree                    │
└─────────────────────────────────────────────────────────────┘

ProviderScope (main.dart)
    │
    ├─> databaseHelperProvider
    │    └─> DatabaseHelper (singleton)
    │         └─> SQLite connection pool
    │
    ├─> asrPlatformServiceProvider
    │    └─> ASRPlatformService
    │         ├─> MethodChannel
    │         ├─> _eventController (StreamController)
    │         ├─> eventStream (broadcast)
    │         ├─> partialTranscriptStream (filtered)
    │         ├─> finalSegmentStream (filtered)
    │         └─> errorStream (filtered)
    │
    ├─> recordingStateProvider
    │    └─> RecordingNotifier
    │         └─> State: RecordingState
    │              ├─> idle
    │              ├─> recording
    │              └─> processing
    │
    ├─> partialTranscriptProvider
    │    └─> String (current partial text)
    │
    ├─> todoListProvider
    │    └─> TodoListNotifier
    │         └─> State: List<TodoItem>
    │              ├─> loadTodos() → Query DB
    │              ├─> addFromSegment() → Insert + Reload
    │              ├─> toggleStatus() → Update + Reload
    │              ├─> updateText() → Update + Reload
    │              ├─> deleteTodo() → Delete + Reload
    │              └─> reorderTodos() → Batch update + Update state
    │
    └─> vadConfigProvider
         └─> VADConfigNotifier
              └─> State: VADConfig
                   ├─> shortPauseMs
                   ├─> longPauseMs
                   └─> energyThreshold
```

---

## 🗂️ Database Schema Visualization

```sql
┌──────────────────────────────────────────────────────────┐
│                    todo_item TABLE                        │
├──────────────┬───────────┬────────┬──────────────────────┤
│ Column       │ Type      │ Null   │ Description          │
├──────────────┼───────────┼────────┼──────────────────────┤
│ id           │ TEXT      │ NO     │ Primary Key (UUID)   │
│ text         │ TEXT      │ NO     │ Todo content         │
│ created_at   │ INTEGER   │ NO     │ Unix timestamp (ms)  │
│ updated_at   │ INTEGER   │ YES    │ Last update time     │
│ audio_path   │ TEXT      │ YES    │ Path to PCM file     │
│ status       │ INTEGER   │ NO     │ 0=pending,1=complete │
│ order_index  │ INTEGER   │ YES    │ Manual sort order    │
│ confidence   │ REAL      │ YES    │ ASR confidence 0-1   │
│ meta         │ TEXT      │ YES    │ JSON metadata        │
└──────────────┴───────────┴────────┴──────────────────────┘

Indexes:
  • idx_created_at ON todo_item(created_at)
  • idx_order_index ON todo_item(order_index)

Sample Data:
┌──────┬────────────────────────┬────────────┬────────┬──────┐
│ id   │ text                   │ created_at │ status │ conf │
├──────┼────────────────────────┼────────────┼────────┼──────┤
│ u1   │ Buy milk and eggs      │ 1234567890 │ 0      │ 0.92 │
│ u2   │ Call mom tomorrow      │ 1234567900 │ 1      │ 0.88 │
│ u3   │ Finish project report  │ 1234567910 │ 0      │ 0.75 │
└──────┴────────────────────────┴────────────┴────────┴──────┘
```

---

## 🎨 UI Component Hierarchy

```
MaterialApp
└─> Scaffold
    ├─> AppBar
    │   ├─> Title: "AudioNotes"
    │   └─> Actions: [Settings IconButton]
    │
    ├─> Body: Stack
    │   ├─> Layer 1: Todo List
    │   │   └─> ReorderableListView.builder
    │   │        └─> TodoItemCard (repeated)
    │   │             ├─> ListTile
    │   │             │    ├─> leading: DragHandle
    │   │             │    ├─> title: Todo text
    │   │             │    ├─> subtitle: Timestamp + Confidence warning
    │   │             │    └─> trailing: Checkbox
    │   │             └─> GestureDetector
    │   │                  ├─> onTap: Edit dialog
    │   │                  └─> onLongPress: Bottom sheet
    │   │
    │   └─> Layer 2: RecordingOverlay (conditional)
    │        └─> Container (semi-transparent)
    │             └─> Card
    │                  ├─> Recording indicator (animated)
    │                  ├─> Status text
    │                  ├─> Partial transcript display
    │                  └─> Guidance text
    │
    └─> FloatingActionButton.extended
         ├─> Icon: mic/stop (dynamic)
         └─> Label: Record/Stop/Processing (dynamic)
```

---

## 🔧 Configuration Points

### Tunable Parameters

```dart
// VAD Configuration
VADConfig(
  shortPauseMs: 600,      // Adjust for faster/slower segmentation
  longPauseMs: 1500,      // Increase for longer sentences
  energyThreshold: 0.3,   // Lower = more sensitive, Higher = less sensitive
)

// Audio Configuration
AudioConfig(
  sampleRate: 16000,      // Don't change (Vosk requirement)
  channels: 1,            // Mono only
  format: 'pcm16',        // 16-bit PCM
)

// Performance Targets
const firstPartialTarget = Duration(milliseconds: 1500);
const finalSegmentTarget = Duration(milliseconds: 500);
const maxCpuUsage = 0.30;  // 30% single core
const maxMemoryMB = 200;
```

---

## 🚦 Error Handling Strategy

```
Error Occurs
    │
    ├─> Permission Denied
    │    ├─> Native plugin returns error event
    │    ├─> Dart catches via errorStream
    │    ├─> Show snackbar with explanation
    │    └─> Provide button to open settings
    │
    ├─> Low Storage
    │    ├─> Check before recording starts
    │    ├─> If < 50MB available, prevent recording
    │    └─> Show dialog: "Free up space to record"
    │
    ├─> Recognition Failure
    │    ├─> Confidence score < 0.5
    │    ├─> Mark todo with low confidence flag
    │    ├─> Show warning icon in UI
    │    └─> Suggest: "Tap to edit or re-record"
    │
    ├─> Database Write Failure
    │    ├─> Transaction rollback
    │    ├─> Delete orphaned audio file
    │    ├─> Log error for debugging
    │    └─> Show retry option to user
    │
    └─> App Crash
         ├─> WAL mode ensures DB integrity
         ├─> On restart: check for incomplete records
         ├─> Clean up temporary files
         └─> Optionally send crash report
```

---

**This visual guide provides a complete picture of the AudioNotes system architecture!** 🎯
