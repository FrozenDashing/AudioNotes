# AudioNotes - Complete File Structure

```
AudioNotes/
│
├── 📱 Application Layer (lib/)
│   ├── main.dart                          # App entry point & theme configuration
│   │
│   ├── 📦 Models (lib/models/)
│   │   ├── todo_item.dart                 # Todo entity with JSON serialization
│   │   └── speech_segment.dart            # ASR segment & partial transcript models
│   │
│   ├── 💾 Data Layer (lib/data/)
│   │   └── database_helper.dart           # SQLite CRUD operations & schema
│   │
│   ├── 🔧 Services (lib/services/)
│   │   └── asr_platform_service.dart      # Platform channel interface for native ASR
│   │
│   ├── ⚡ State Management (lib/providers/)
│   │   └── app_providers.dart             # Riverpod providers & notifiers
│   │
│   ├── 🖼️ Screens (lib/screens/)
│   │   └── home_screen.dart               # Main todo list screen with recording
│   │
│   └── 🧩 Widgets (lib/widgets/)
│       ├── todo_item_card.dart            # Individual todo card with edit/delete
│       └── recording_overlay.dart         # Recording status overlay UI
│
├── 🤖 Android Native (android/)
│   └── src/main/kotlin/com/audionotes/audio_notes/
│       └── AsrPlugin.kt                   # AudioRecord + VAD + Vosk integration
│
├── 🍎 iOS Native (ios/)
│   └── Classes/
│       └── AsrPlugin.swift                # AVAudioEngine + VAD + Vosk integration
│
├── 🧪 Tests (test/)
│   └── models/
│       └── todo_item_test.dart            # Unit tests for data models
│
├── 📝 Documentation
│   ├── README.md                          # Main documentation & overview
│   ├── SETUP.md                           # Detailed setup instructions
│   ├── CONTRIBUTING.md                    # Contribution guidelines
│   ├── CHANGELOG.md                       # Version history
│   ├── PROJECT_SUMMARY.md                 # MVP summary & architecture
│   ├── QUICK_REFERENCE.md                 # Developer quick reference
│   └── devlogs/
│       ├── prompts/
│       │   └── demand_analysis.md         # Requirements analysis
│       └── stages/
│           └── mvp.md                     # MVP architecture specification
│
├── ⚙️ Configuration
│   ├── pubspec.yaml                       # Dependencies & project metadata
│   ├── analysis_options.yaml              # Linter rules
│   └── .gitignore                         # Git ignore patterns
│
└── 📄 Legal
    └── LICENSE                            # MIT License
```

## Module Dependencies

```
main.dart
  └─> ProviderScope
       └─> HomeScreen
            ├─> todoListProvider (Riverpod)
            │    └─> databaseHelperProvider
            ├─> recordingStateProvider
            ├─> partialTranscriptProvider
            └─> TodoItemCard widgets
                 └─> Individual todo operations
                      ├─> Toggle status
                      ├─> Edit text
                      ├─> Delete
                      └─> Reorder

asr_platform_service.dart
  ├─> MethodChannel: "com.audionotes/asr"
  ├─> Stream: partial_transcript
  ├─> Stream: final_segment
  └─> Commands: start, stop, cancel, reRecord

database_helper.dart
  ├─> Table: todo_item
  ├─> insertTodo()
  ├─> getAllTodos()
  ├─> updateTodo()
  ├─> deleteTodo()
  └─> updateOrderIndices()

Native Plugins (Android/iOS)
  ├─> Audio Capture
  ├─> VAD Processing
  ├─> Vosk ASR Recognition
  └─> Event Callbacks to Dart
```

## Data Flow Diagram

```
User Action
    │
    ├─> Tap Record Button
    │     └─> recordingStateProvider → RecordingState.recording
    │          └─> asrPlatformService.startRecording()
    │               └─> Native Plugin starts AudioRecord/AVAudioEngine
    │                    └─> Audio frames → VAD → Vosk ASR
    │                         ├─> Partial transcripts → Dart stream
    │                         │    └─> partialTranscriptProvider updates
    │                         │         └─> RecordingOverlay shows real-time text
    │                         └─> Final segment detected (VAD silence)
    │                              └─> Save audio file + Send to Dart
    │                                   └─> todoListNotifier.addFromSegment()
    │                                        └─> databaseHelper.insertTodo()
    │                                             └─> UI rebuilds with new todo
    │
    ├─> Tap Checkbox
    │     └─> todoListNotifier.toggleStatus()
    │          └─> databaseHelper.updateTodo()
    │               └─> UI updates (strikethrough)
    │
    ├─> Drag & Drop
    │     └─> todoListNotifier.reorderTodos()
    │          └─> databaseHelper.updateOrderIndices()
    │               └─> New order persisted
    │
    └─> Long Press → Edit/Delete/Re-record
          ├─> Edit: Show dialog → Update text → Save to DB
          ├─> Delete: Confirm → Remove from DB → UI update
          └─> Re-record: Start new recording → Replace audio & text
```

## State Management Architecture

```
Riverpod Providers
│
├─> databaseHelperProvider (Provider)
│    └─> Singleton DatabaseHelper instance
│
├─> asrPlatformServiceProvider (Provider)
│    └─> ASRPlatformService with event streams
│
├─> recordingStateProvider (StateNotifierProvider)
│    └─> RecordingNotifier
│         └─> State: idle | recording | processing
│
├─> partialTranscriptProvider (StateProvider)
│    └─> Current partial recognition text
│
├─> todoListProvider (StateNotifierProvider)
│    └─> TodoListNotifier
│         ├─> List<TodoItem> state
│         ├─> loadTodos()
│         ├─> addFromSegment()
│         ├─> toggleStatus()
│         ├─> updateText()
│         ├─> deleteTodo()
│         └─> reorderTodos()
│
└─> vadConfigProvider (StateNotifierProvider)
     └─> VADConfigNotifier
          └─> VAD parameters (pause thresholds, energy)
```

## Key Design Patterns

1. **Repository Pattern**: DatabaseHelper abstracts SQLite operations
2. **Provider Pattern**: Riverpod for reactive state management
3. **Observer Pattern**: Streams for ASR events
4. **Command Pattern**: Platform channel commands (start, stop, etc.)
5. **DTO Pattern**: JSON serializable models for data transfer
6. **Singleton Pattern**: DatabaseHelper instance
7. **Factory Pattern**: Model creation from JSON/maps
8. **Strategy Pattern**: VAD configurable parameters
9. **Template Method**: Platform-specific implementations (Android/iOS)
10. **MVC Pattern**: Separation of Models, Views (Widgets), Controllers (Providers)

---

*This structure ensures maintainability, testability, and scalability.*
