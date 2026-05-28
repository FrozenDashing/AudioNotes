# AudioNotes API Interaction Architecture

## Overview
The AudioNotes application implements a layered architecture with clear separation between frontend UI components and backend processing services. The API interactions follow a reactive pattern using Riverpod state management, with additional platform channel communication for native operations.

## Frontend-Backend Communication Layers

### 1. Riverpod State Management Layer
The primary communication mechanism between UI and business logic uses Riverpod providers:

```
UI Layer (Widgets) ←→ Riverpod Providers ←→ Service Layer ←→ Data Layer
```

#### Provider Types Used:
- **Provider**: For singleton services and repositories
- **NotifierProvider**: For mutable state (recording state, partial transcript)
- **AsyncNotifierProvider**: For asynchronous data (todo list, categories, tags)
- **FutureProvider**: For one-time async operations (loading lists)

### 2. Service Layer Interface
Backend services are accessed through dedicated providers:

```
[recorderServiceProvider](../lib/providers/app_providers.dart#L141-L143) ←→ RecorderService (Audio recording)
[recognitionServiceProvider](../lib/providers/app_providers.dart#L153-L155) ←→ RecognitionService (Speech recognition)
[todoRepositoryProvider](../lib/providers/app_providers.dart#L52-L54) ←→ TodoRepository (Todo data operations)
[databaseHelperProvider](../lib/providers/app_providers.dart#L49-L51) ←→ DatabaseHelper (SQLite operations)
[modelManagerServiceProvider](../lib/providers/app_providers.dart#L159-L161) ←→ ModelManagerService (Vosk model management)
```

## API Interaction Flows

### 1. Recording Process API Flow
```
UI (HomeScreen) → [recordingStateProvider](../lib/providers/app_providers.dart#L276-L278).start() → RecorderService.startRecording() → Native Platform Channel → Audio Recording → [recordingStateProvider](../lib/providers/app_providers.dart#L276-L278) → UI Update
```

#### Detailed Steps:
1. User presses record button in UI
2. UI calls `recordingStateProvider.notifier.start()`
3. RecordingNotifier.start() calls RecorderService.startRecording()
4. RecorderService communicates with native layer via platform channels
5. Native layer captures audio and saves to file
6. Recording state updates to "recording"
7. UI updates to reflect recording state
8. Partial transcripts stream to [partialTranscriptProvider](../lib/providers/app_providers.dart#L289-L291)
9. UI updates real-time transcription

### 2. Recognition Process API Flow
```
UI (HomeScreen) → [recordingStateProvider](../lib/providers/app_providers.dart#L276-L278).stop() → RecognitionService.recognize() → Native ASR → Recognition Result → TodoRepository.insert() → DatabaseHelper.insertTodo() → [todoListProvider](../lib/providers/app_providers.dart#L774-L777) → UI Refresh
```

#### Detailed Steps:
1. User stops recording
2. RecordingNotifier.stop() gets audio file path
3. RecognitionService recognizes audio using Vosk
4. Recognition result includes text and confidence
5. TodoRepository creates todo with audio path and recognized text
6. DatabaseHelper.inserts todo into SQLite database
7. [todoListProvider](../lib/providers/app_providers.dart#L774-L777) refreshes from database
8. UI updates to show new todo item

### 3. Todo Management API Flow
```
UI (TodoItemCard) → [todoListProvider](../lib/providers/app_providers.dart#L774-L777).notifier → TodoRepository → DatabaseHelper → SQLite Database → [todoListProvider](../lib/providers/app_providers.dart#L774-L777) → UI Update
```

#### Supported Operations:
- **Toggle Completion**: `todoListProvider.notifier.toggleStatus()` → `TodoRepository.toggleStatus()` → `DatabaseHelper.updateTodo()`
- **Update Text**: `todoListProvider.notifier.updateText()` → `DatabaseHelper.updateTodo()`
- **Delete Todo**: `todoListProvider.notifier.deleteTodo()` → `DatabaseHelper.deleteTodo()`
- **Reorder Todos**: `todoListProvider.notifier.reorderTodos()` → `DatabaseHelper.updateOrderIndices()`
- **Update Priority**: `todoListProvider.notifier.updatePriority()` → `DatabaseHelper.updatePriority()`
- **Update Reminders**: `todoListProvider.notifier.updateReminderTime()` → `DatabaseHelper.upsertReminder()`

## Native Platform Communication

### Platform Channel Interface
The application uses platform channels to communicate with native audio recording and ASR capabilities:

```
Dart Layer ↔ MethodChannel ↔ Native Layer (Android/iOS)
```

#### Available Methods:
- `startRecording`: Begin audio capture
- `stopRecording`: End audio capture and return file path
- `cancelRecording`: Cancel ongoing recording
- `reRecord`: Replace audio for existing todo
- `reloadModel`: Reload ASR model
- `isModelReady`: Check if ASR model is loaded

#### Event Streams:
- `partial_transcript`: Real-time partial recognition results
- `final_segment`: Completed recognition segment
- `recording_status`: Recording state updates

## Data Flow Patterns

### 1. Read Operations
```
UI Widget → Riverpod Consumer → Provider → Repository → DatabaseHelper → SQLite → Repository → Provider → UI Widget
```

### 2. Write Operations  
```
UI Widget → Riverpod Consumer → Provider.notifier → Repository → DatabaseHelper → SQLite → Repository → Provider → UI Update
```

### 3. Async Operations
```
UI Widget → FutureProvider → Repository → DatabaseHelper → SQLite → Result → FutureProvider → UI Widget
```

## Error Handling in API Interactions

### Frontend Error Handling
- UI displays error messages using SnackBar
- Graceful fallback states for failed operations
- Retry mechanisms for transient failures

### Backend Error Handling
- Repository layer catches and handles database errors
- Service layer manages native platform communication errors
- Provider layer propagates errors to UI components

## Performance Considerations

### State Update Optimization
- Granular state updates using specific providers
- Batch operations for multiple changes
- Background processing for intensive operations

### Data Consistency
- Transaction-based database operations
- Atomic updates for related data
- State synchronization between UI and database

This API interaction architecture ensures clean separation of concerns while maintaining efficient communication between all application layers.