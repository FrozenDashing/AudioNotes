# AudioNotes - Complete Architecture

## Project Structure

```
AudioNotes/
│
├── 📱 Application Layer (lib/)
│   ├── main.dart                          # App entry point & theme configuration
│   │
│   ├── 📦 Models (lib/models/)
│   │   ├── todo_item.dart                 # Todo entity with JSON serialization
│   │   ├── todo_group.dart                # Todo group entity for category organization
│   │   ├── category.dart                  # Category entity
│   │   ├── tag.dart                       # Tag entity
│   │   ├── speech_segment.dart            # ASR segment & partial transcript models
│   │   ├── todo_query_options.dart        # Query options for filtering/sorting
│   │   ├── todo_sort.dart                 # Sorting options
│   │   ├── todo_priority.dart             # Priority levels
│   │   └── todo_drag_data.dart            # Drag and drop data model
│   │
│   ├── 💾 Data Layer (lib/data/)
│   │   ├── database_helper.dart           # SQLite CRUD operations & schema
│   │   ├── todo_repository.dart           # Todo data abstraction
│   │   ├── category_repository.dart       # Category data abstraction
│   │   ├── tag_repository.dart            # Tag data abstraction
│   │   └── reminder_repository.dart       # Reminder data abstraction
│   │
│   ├── 🔧 Services (lib/services/)
│   │   ├── asr_platform_service.dart      # Platform channel interface for native ASR
│   │   ├── todo_grouping_service.dart     # Service for organizing todos by category
│   │   ├── recorder_service.dart          # Audio recording service
│   │   ├── recognition_service.dart       # Speech recognition service
│   │   ├── notification_service.dart      # Local notification service
│   │   ├── awesome_notification_service.dart # Enhanced notification service
│   │   ├── reminder_service.dart          # Reminder scheduling service
│   │   ├── model_manager_service.dart     # Vosk model management
│   │   ├── settings_service.dart          # Settings management
│   │   ├── audio_playback_service.dart    # Audio playback service
│   │   ├── calendar_sync_service.dart     # Calendar integration service
│   │   ├── widget_sync_service.dart       # Widget synchronization service
│   │   ├── text_input_service.dart        # Text input processing service
│   │   └── widget_service.dart           # Widget management service
│   │
│   ├── ⚡ State Management (lib/providers/)
│   │   └── app_providers.dart             # Riverpod providers & notifiers
│   │   └── settings_provider.dart         # Settings state management
│   │
│   ├── 🖼️ Screens (lib/screens/)
│   │   ├── home_screen.dart               # Main todo list screen with category grouping
│   │   ├── category_create_screen.dart    # Category creation UI
│   │   ├── category_picker_screen.dart    # Category selection UI
│   │   ├── tag_create_screen.dart         # Tag creation UI
│   │   ├── tag_picker_screen.dart         # Tag selection UI
│   │   ├── settings_screen.dart           # Settings UI
│   │   └── model_selection_screen.dart    # Model selection UI
│   │
│   └── 🧩 Widgets (lib/widgets/)
│       ├── todo_item_card.dart            # Individual todo card with edit/delete
│       ├── todo_group_section.dart        # Todo group section with category header
│       ├── recording_overlay.dart         # Recording status overlay UI
│       ├── audio_player_widget.dart       # Audio playback controls
│       ├── floating_action_toolbar.dart   # Batch operation toolbar
│       ├── theme_color_picker.dart        # Theme color selection
│       └── font_size_slider.dart          # Font size adjustment
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
│   ├── README_ZH.md                       # Chinese version documentation
│   ├── ARCHITECTURE.md                    # Architecture overview
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
            │    └─> todoGroupingService
            ├─> recordingStateProvider
            ├─> partialTranscriptProvider
            ├─> settingsProvider
            └─> TodoGroupSection widgets
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
  ├─> Tables: todo_item, categories, tags, todo_tags, reminders
  ├─> insertTodo()
  ├─> getAllTodos()
  ├─> getTodosByCategory()
  ├─> getTodosByTag()
  ├─> updateTodo()
  ├─> deleteTodo()
  ├─> insertCategory()
  ├─> insertTag()
  ├─> upsertReminder()
  └─> updateOrderIndices()

Native Plugins (Android/iOS)
  ├─> Audio Capture
  ├─> VAD Processing
  ├─> Vosk ASR Recognition
  └─> Event Callbacks to Dart

todo_grouping_service.dart
  ├─> Receives flat todo list
  ├─> Groups todos by category
  ├─> Sorts groups and items within groups
  └─> Returns structured TodoGroup list

notification_service.dart
  ├─> Schedule local notifications
  ├─> Handle notification tap events
  └─> Manage notification permissions
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
    │                                             └─> todoGroupingService.organizeByCategory()
    │                                                  └─> UI rebuilds with grouped todos
    │
    ├─> Tap Checkbox
    │     └─> todoListNotifier.toggleStatus()
    │          └─> databaseHelper.updateTodo()
    │               └─> UI updates (strikethrough)
    │
    ├─> Drag & Drop (within group)
    │     └─> todoListNotifier.reorderTodos()
    │          └─> databaseHelper.updateOrderIndices()
    │               └─> New order persisted
    │
    ├─> Drag & Drop (groups)
    │     └─> todoListNotifier.reorderGroups()
    │          └─> update group order in settings
    │               └─> New group order persisted
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
│         ├─> reorderTodos()
│         └─> reorderGroups()
│
├─> settingsProvider (StateNotifierProvider)
│    └─> SettingsNotifier
│         └─> App settings (theme, font size, defaults)
│
├─> todoGroupingServiceProvider (Provider)
│    └─> TodoGroupingService
│         └─> Organizes todos into groups by category
│
└─> vadConfigProvider (StateNotifierProvider)
     └─> VADConfigNotifier
          └─> VAD parameters (pause thresholds, energy)
```

## Key Design Patterns

1. **Repository Pattern**: DatabaseHelper and Repository classes abstract SQLite operations
2. **Provider Pattern**: Riverpod for reactive state management
3. **Observer Pattern**: Streams for ASR events and state changes
4. **Command Pattern**: Platform channel commands (start, stop, etc.)
5. **DTO Pattern**: JSON serializable models for data transfer
6. **Singleton Pattern**: DatabaseHelper and service instances
7. **Factory Pattern**: Model creation from JSON/maps
8. **Strategy Pattern**: VAD configurable parameters
9. **Template Method**: Platform-specific implementations (Android/iOS)
10. **MVC Pattern**: Separation of Models, Views (Widgets), Controllers (Providers)
11. **Decorator Pattern**: TodoGroupSection wraps TodoItemCards with category context
12. **Adapter Pattern**: TodoGroupingService adapts flat list to grouped structure
13. **Facade Pattern**: Services provide simplified interfaces to complex subsystems

## Category Grouping Architecture

The category grouping feature introduces a new layer that transforms the flat todo list into a hierarchical structure:

```
Flat Todo List → TodoGroupingService → Grouped Todo Structure → UI
    ↓                    ↓                      ↓              ↓
[Todo A(cat1),    Organize by category    [Group cat1:     Render as
 Todo B(cat2),  →  Sort groups & items  →  [Todo A,        collapsible
 Todo C(cat1)]                             Todo C],        sections
                                          Group cat2:
                                          [Todo B]]
```

This architecture ensures maintainability, testability, and scalability while preserving the core functionality of the offline speech-to-text todo application.