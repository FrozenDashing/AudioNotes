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
├── assets/                     # Static assets (models, images)
│   └── models/                 # Vosk ASR models (not in repo, downloaded separately)
├── devlogs/                    # Development logs and planning documents
│   ├── issues/                 # Issue tracking and solutions
│   │   └── kotlin_cache_error.md
│   ├── prompts/                # Development prompts
│   │   └── demand_analysis.md
│   └── stages/                 # Development stage documents
│       ├── QOL/                # Quality of life improvements
│       │   └── to_improve.md
│       ├── develop/            # Development plans
│       │   ├── development_plan.md
│       │   └── settings-develop.md
│       └── mvp/                # MVP stage documents
│           ├── guidance.md
│           ├── instruction.md
│           ├── revision.md
│           └── revision2.md
├── ios/                        # iOS native implementation
│   ├── Flutter/                # Flutter engine files
│   └── Runner/                 # iOS app source code (Swift)
├── lib/                        # Main Flutter application source code
│   ├── data/                   # Data sources and database helpers
│   │   ├── database_helper.dart
│   │   └── todo_repository.dart
│   ├── domain/                 # Business logic and use cases
│   │   └── usecases/
│   │       └── create_todo_from_recording_usecase.dart
│   ├── models/                 # Data models
│   │   ├── model_metadata.dart # Model metadata for ASR models
│   │   ├── settings_state.dart # Settings state model
│   │   ├── speech_segment.dart # Speech segment model
│   │   └── todo_item.dart      # Todo item model
│   ├── providers/              # Riverpod state providers
│   │   ├── app_providers.dart  # Main app providers
│   │   └── settings_provider.dart # Settings provider
│   ├── repositories/           # Data abstraction layer
│   │   ├── model_repository.dart # Model metadata repository
│   │   └── settings_repository.dart # Settings repository
│   ├── screens/                # UI screens
│   │   ├── home_screen.dart    # Main home screen
│   │   ├── model_selection_screen.dart # Model selection screen
│   │   └── settings_screen.dart # Settings screen
│   ├── services/               # Business logic services
│   │   ├── asr_platform_service.dart # ASR platform service
│   │   ├── audio_playback_service.dart # Audio playback service
│   │   ├── model_manager_service.dart # Model manager service
│   │   ├── recognition_service.dart # Recognition service
│   │   ├── recorder_service.dart # Recording service
│   │   └── settings_service.dart # Settings service
│   ├── utils/                  # Utility functions
│   │   ├── audio_chunker.dart  # Audio chunking utilities
│   │   └── audio_file_cleanup.dart # Audio file cleanup utilities
│   ├── widgets/                # Reusable UI components
│   │   ├── audio_player_widget.dart # Audio player widget
│   │   ├── completed_text.dart # Completed text widget
│   │   ├── floating_action_toolbar.dart # Floating action toolbar
│   │   ├── font_size_slider.dart # Font size slider widget
│   │   ├── recording_overlay.dart # Recording overlay widget
│   │   ├── theme_color_picker.dart # Theme color picker widget
│   │   └── todo_item_card.dart # Todo item card widget
│   └── main.dart               # Application entry point
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
├── PROJECT_SUMMARY.md          # Project summary
├── QUICK_REFERENCE.md          # Quick reference guide
├── README.md                   # Main project documentation
├── SETUP.md                    # Setup instructions
├── VISUAL_OVERVIEW.md          # Visual overview of the app
├── analysis_options.yaml       # Dart analysis configuration
├── pubspec.yaml                # Project dependencies and assets
└── .gitignore                  # Git ignore rules
```

## Key Directories and Files Explained

### `lib/` - Main Application Code
This is the heart of the Flutter application containing all Dart code:

- **`data/`**: Handles database interactions and data access using SQLite through the `sqflite` package.
- **`domain/`**: Contains business logic and use cases, following Clean Architecture principles.
- **[models/](./lib/models)**: Defines data structures used throughout the application.
- **[providers/](./lib/providers)**: Manages state using Riverpod for reactive programming.
- **[repositories/](./lib/repositories)**: Provides abstraction for data operations.
- **[screens/](./lib/screens)**: Contains the main UI screens of the application.
- **[services/](./lib/services)**: Implements core business logic like audio recording, speech recognition, and model management.
- **[widgets/](./lib/widgets)**: Reusable UI components that can be composed to build screens.

### `android/` and `ios/` - Native Code
These directories contain platform-specific implementations for accessing native APIs:

- **`android/src/main/kotlin/`**: Contains Kotlin code for Android native plugins, especially for microphone access and ASR integration.
- **`ios/Classes/`**: Contains Swift code for iOS native plugins.

### `devlogs/` - Development Documentation
Contains various documents tracking development progress, issues, and plans:

- **`stages/mvp/`**: Documents related to the Minimum Viable Product stage.
- **`stages/develop/`**: Development planning documents.
- **`issues/`**: Solutions to encountered issues like Kotlin cache errors.

### `assets/` - Static Resources
Contains static assets that are bundled with the application, particularly ASR models for offline speech recognition.

## Key Files

- **`pubspec.yaml`**: Defines project dependencies, assets, and metadata.
- **`lib/main.dart`**: Entry point of the Flutter application.
- **[lib/screens/home_screen.dart](./lib/screens/home_screen.dart)**: Main screen where users record audio and see transcribed todos.
- **[lib/services/asr_platform_service.dart](./lib/services/asr_platform_service.dart)**: Core service that interfaces with Vosk ASR for speech recognition.
- **[lib/providers/settings_provider.dart](./lib/providers/settings_provider.dart)**: Manages application settings using Riverpod.