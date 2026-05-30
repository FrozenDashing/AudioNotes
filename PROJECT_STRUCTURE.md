# AudioNotes Project Structure

This document provides an overview of the AudioNotes project structure and explains the purpose of each directory and file.

## Directory Structure

```
AudioNotes/
├── android/                    # Android native implementation
│   ├── app/
│   │   └── src/
│   │       ├── debug/          # Debug configuration
│   │       ├── main/           # Main Android source code (Kotlin)
│   │       │   ├── java/
│   │       │   ├── kotlin/     # Kotlin source files for native plugins
│   │       │   ├── res/        # Android resources
│   │       │   └── AndroidManifest.xml
│   │       └── profile/        # Profile configuration
│   ├── gradle.properties       # Gradle configuration
│   └── gradlew.bat             # Gradle wrapper (Windows)
├── assets/                     # Static assets (models, i18n)
│   ├── models/                 # Vosk ASR models (not in repo, downloaded separately)
│   └── i18n/                   # Internationalization files (en.json, zh_CN.json)
├── devlogs/                    # Development logs and planning documents
│   ├── issues/                 # Issue tracking and solutions
│   │   └── kotlin_cache_error.md
│   ├── prompts/                # Development prompts
│   │   └── demand_analysis.md
│   └── stages/                 # Development stage documents
│       ├── QOL/                # Quality of life improvements
│       │   └── to_improve.md
│       ├── UI/                 # UI/UX development documents
│       │   └── category分组视图下一阶段大改造执行文档.md
│       ├── develop/            # Development plans
│       │   ├── development_plan.md
│       │   └── settings-develop.md
│       └── mvp/                # MVP stage documents
│           └── ... 4 files, 0 dirs not shown
├── ios/                        # iOS native implementation
│   ├── Flutter/                # Flutter engine files
│   └── Runner/                 # iOS app source code (Swift)
├── lib/                        # Main Flutter application source code (Clean Architecture)
│   ├── data/                   # Data sources and database helpers
│   │   ├── category_repository.dart
│   │   ├── database_helper.dart
│   │   ├── reminder_repository.dart
│   │   ├── tag_repository.dart
│   │   ├── todo_query_builder.dart
│   │   └── todo_repository.dart
│   ├── domain/                 # Business logic and use cases
│   │   └── usecases/
│   │       ├── create_todo_from_recording_usecase.dart
│   │       ├── create_todo_from_text_usecase.dart # Text input use case
│   │       └── sync_calendar_usecase.dart # Calendar sync use case
│   ├── models/                 # Data models
│   │   ├── category.dart       # Category model
│   │   ├── model_metadata.dart # Model metadata for ASR models
│   │   ├── settings_state.dart # Settings state model
│   │   ├── speech_segment.dart # Speech segment model
│   │   ├── tag.dart           # Tag model
│   │   ├── todo_drag_data.dart # Drag and drop data model
│   │   ├── todo_group.dart    # Todo group model for category grouping
│   │   ├── todo_item.dart     # Todo item model (comprehensive with priority, due dates, etc.)
│   │   ├── todo_priority.dart # Todo priority model
│   │   ├── todo_query_options.dart # Query options model
│   │   ├── todo_sort.dart     # Sorting model
│   │   ├── widget_config.dart # Widget configuration model
│   │   └── calendar_event.dart # Calendar event sync model
│   ├── providers/              # Riverpod state providers
│   │   ├── app_providers.dart  # Main app providers
│   │   ├── settings_provider.dart # Settings provider
│   │   └── widget_provider.dart # Widget state provider
│   ├── repositories/           # Data abstraction layer
│   │   ├── model_repository.dart # Model metadata repository
│   │   ├── settings_repository.dart # Settings repository
│   │   └── calendar_repository.dart # Calendar sync repository
│   ├── screens/                # UI screens
│   │   ├── settings/           # Settings-related screens
│   │   │   └── ... 3 files, 0 dirs not shown
│   │   ├── category_create_screen.dart # Category creation screen
│   │   ├── category_picker_screen.dart # Category selection screen
│   │   ├── home_screen.dart    # Main home screen with category grouping
│   │   ├── model_selection_screen.dart # Model selection screen
│   │   ├── settings_screen.dart # Settings screen
│   │   ├── tag_create_screen.dart # Tag creation screen
│   │   ├── tag_picker_screen.dart # Tag selection screen
│   │   ├── trash_screen.dart  # Deleted items management screen
│   │   ├── text_input_screen.dart # Manual text input screen
│   │   └── widget_config_screen.dart # Widget configuration screen
│   ├── services/               # Business logic services
│   │   ├── asr_platform_service.dart # ASR platform service
│   │   ├── audio_playback_service.dart # Audio playback service
│   │   ├── model_manager_service.dart # Model manager service
│   │   ├── notification_service.dart # Notification service
│   │   ├── recognition_service.dart # Recognition service
│   │   ├── recorder_service.dart # Recording service
│   │   ├── reminder_service.dart # Reminder service
│   │   ├── settings_service.dart # Settings service
│   │   ├── todo_grouping_service.dart # Todo grouping service for category organization
│   │   ├── awesome_notification_service.dart # Enhanced notifications
│   │   ├── calendar_sync_service.dart # Calendar integration
│   │   ├── widget_sync_service.dart # Widget synchronization
│   │   ├── text_input_service.dart # Text input processing service
│   │   └── widget_service.dart # Widget management service
│   ├── utils/                  # Utility functions
│   │   ├── audio_chunker.dart  # Audio chunking utilities
│   │   ├── audio_file_cleanup.dart # Audio file cleanup utilities
│   │   ├── text_formatter.dart # Text formatting utilities
│   │   └── widget_helper.dart # Widget helper utilities
│   ├── widgets/                # Reusable UI components
│   │   ├── audio_player_widget.dart # Audio player widget
│   │   ├── completed_text.dart # Completed text widget
│   │   ├── floating_action_toolbar.dart # Floating action toolbar
│   │   ├── font_size_slider.dart # Font size slider widget
│   │   ├── recording_overlay.dart # Recording overlay widget
│   │   ├── theme_color_picker.dart # Theme color picker widget
│   │   ├── todo_group_section.dart # Todo group section widget for category grouping
│   │   ├── todo_item_card.dart # Todo item card widget
│   │   ├── text_input_widget.dart # Text input widget for manual todo creation
│   │   ├── home_widget.dart # Home screen widget for quick access
│   │   ├── widget_configuration.dart # Widget configuration UI
│   │   └── calendar_sync_widget.dart # Calendar sync status widget
│   └── main.dart               # Application entry point
├── review/                     # Project review and analysis documents
├── test/                       # Test files
│   ├── models/                 # Model tests
│   │   └── todo_item_test.dart
│   └── widget_test.dart        # Widget tests
├── web/                        # Web platform files (if applicable)
│   ├── index.html
│   └── manifest.json
├── windows/                    # Windows platform files (if applicable)
├── linux/                      # Linux platform files (if applicable)
├── macos/                      # macOS platform files (if applicable)
├── ARCHITECTURE.md             # Detailed architecture documentation
├── CHANGELOG.md                # Version history
├── CONTRIBUTING.md             # Contribution guidelines
├── PROJECT_STRUCTURE.md        # Project structure documentation
├── QUICK_START.md              # Quick start guide
├── README.md                   # Main project documentation (with Chinese version link)
├── README_ZH.md                # Chinese version documentation
├── analysis_options.yaml       # Dart analysis configuration
├── devtools_options.yaml       # DevTools configuration
└── pubspec.yaml                # Project dependencies and assets (version 3.2.7+1)
```

## Key Directories and Files Explained

### `lib/` - Main Application Code
This is the heart of the Flutter application containing all Dart code:

- **`data/`**: Handles database interactions and data access using SQLite through the `sqflite` package.
- **`domain/`**: Contains business logic and use cases, following Clean Architecture principles.
- **`models/`**: Defines data structures used throughout the application, including the new category grouping models.
- **`providers/`**: Manages state using Riverpod for reactive programming.
- **`repositories/`**: Provides abstraction for data operations.
- **`screens/`**: Contains the main UI screens of the application.
- **`services/`**: Implements core business logic like audio recording, speech recognition, notifications, and the new todo grouping service.
- **`widgets/`**: Reusable UI components that can be composed to build screens, including the new category grouping widgets.

### `android/` and `ios/` - Native Code
These directories contain platform-specific implementations for accessing native APIs:

- **`android/src/main/kotlin/`**: Contains Kotlin code for Android native plugins, especially for microphone access and ASR integration.
- **`ios/Classes/`**: Contains Swift code for iOS native plugins.

### `devlogs/` - Development Documentation
Contains various documents tracking development progress, issues, and plans:

- **`stages/UI/`**: Documents related to UI/UX improvements, including the category grouping implementation guide.
- **`stages/mvp/`**: Documents related to the Minimum Viable Product stage.
- **`stages/develop/`**: Development planning documents.
- **`issues/`**: Solutions to encountered issues like Kotlin cache errors.

### `assets/` - Static Resources
Contains static assets that are bundled with the application, particularly ASR models for offline speech recognition.

## Key Files

- **`pubspec.yaml`**: Defines project dependencies, assets, and metadata.
- **`lib/main.dart`**: Entry point of the Flutter application.
- **`lib/screens/home_screen.dart`**: Main screen where users record audio and see transcribed todos organized by category.
- **`lib/services/todo_grouping_service.dart`**: Core service that organizes todos by category for the UI.
- **`lib/widgets/todo_group_section.dart`**: Widget that displays todos grouped by category.
- **`lib/models/todo_group.dart`**: Data model representing a group of todos by category.
- **`lib/providers/settings_provider.dart`**: Manages application settings using Riverpod.