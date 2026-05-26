# AudioNotes - Offline Speech-to-Text Todo Application

AudioNotes is an offline-first mobile application that converts speech into actionable todo items using Vosk Automatic Speech Recognition (ASR). Designed for productivity, it allows users to record thoughts hands-free and automatically generates organized todo lists without requiring internet connectivity.

## 🚀 Features

### Core Functionality
- **Offline Speech Recognition**: Powered by Vosk ASR engine, works completely offline without internet dependency
- **Real-time Transcription**: Streams partial results as the user speaks for immediate feedback
- **Voice Activity Detection (VAD)**: Automatically segments sentences based on pauses for better organization
- **Smart Todo Creation**: Converts spoken thoughts into structured todo items with timestamps
- **Audio Playback**: Each todo includes the original audio recording for reference
- **Todo Management**: Create, edit, reorder, and complete tasks with intuitive UI

### Advanced Features
- **Model Management**: Download, switch, and manage multiple ASR models for different languages/accents
- **Customizable Interface**: Adjust theme colors, font sizes, and UI elements to personal preference
- **Persistent Storage**: All data stored locally using SQLite with audio files saved securely
- **Cross-platform Support**: Works seamlessly on both Android and iOS devices

## 🛠️ Tech Stack

### Frontend
- **Framework**: [Flutter](https://flutter.dev/) (SDK >= 3.0.0)
- **Language**: [Dart](https://dart.dev/) (SDK >= 3.0.0)
- **State Management**: [Riverpod](https://riverpod.dev/) for reactive state management
- **UI Components**: Material Design 3 with responsive layouts
- **UI Architecture**: Clean Architecture with separation of concerns

### Backend / Native
- **Android**: [Kotlin](https://kotlinlang.org/) (Min API 21)
- **iOS**: [Swift](https://developer.apple.com/swift/) (Min iOS 12.0)
- **ASR Engine**: [Vosk](https://alphacephei.com/vosk/) for offline speech recognition
- **Platform Channels**: MethodChannel for Dart-native communication

### Data & Storage
- **Database**: SQLite (via [sqflite](https://pub.dev/packages/sqflite) package)
- **Audio Format**: PCM16 for high-quality recordings
- **Persistence**: SharedPreferences for settings and preferences
- **Model Storage**: Local file system for ASR models

### Dependencies
- `flutter_riverpod`: State management
- `sqflite`: SQLite database access
- `path_provider`: File system paths
- `permission_handler`: Runtime permissions
- `audioplayers`: Audio playback
- `shared_preferences`: Settings persistence
- `equatable`: Object comparison
- `json_annotation`: JSON serialization
- `http`: Network requests for model downloads

## 🏗️ Architecture

AudioNotes follows Clean Architecture principles with three main layers:

```
┌─────────────────┐    ┌─────────────────────┐    ┌──────────────────┐
│   Presentation  │───▶│     Domain          │───▶│      Data        │
│   (UI/Widgets)  │    │ (Business Logic)    │    │  (Repositories)  │
│                 │    │                     │    │                  │
│ • Screens       │    │ • Use Cases         │    │ • TodoRepo      │
│ • Widgets       │    │ • Entities          │    │ • ModelRepo     │
│ • Providers     │    │                     │    │ • Database      │
└─────────────────┘    └─────────────────────┘    └──────────────────┘
```

### Key Components
- **UI Layer**: Flutter widgets and screens with Riverpod state management
- **Domain Layer**: Business rules and use cases for todo creation and management
- **Data Layer**: Local database, file system, and external service abstractions

## 📱 Usage

1. **Start Recording**: Tap the recording button to begin speaking
2. **Automatic Segmentation**: The app detects pauses to separate thoughts
3. **Real-time Transcription**: See partial results as you speak
4. **Todo Creation**: Completed segments automatically become todo items
5. **Manage Tasks**: Edit, complete, or play back original audio for each item
6. **Customize**: Adjust settings like theme, font size, and model selection

## 🛠️ Development Setup

### Prerequisites
- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- Android Studio or VS Code with Flutter plugin
- Git

### Installation
```bash
# 1. Clone the repository
git clone <repository-url>
cd AudioNotes

# 2. Install dependencies
flutter pub get

# 3. Setup Vosk models (download and place in assets/models/)
# Download model from https://alphacephei.com/vosk/models

# 4. Run the application
flutter run
```

### Development Commands
```bash
# Run tests
flutter test

# Analyze code quality
flutter analyze

# Format code
dart format .

# Build for production
flutter build apk --release  # Android
flutter build ios --release  # iOS
```

## 📁 Project Structure

The project follows a Clean Architecture pattern with clear separation of concerns:

- `lib/` - Main application code
  - `data/` - Database helpers and data sources
  - `domain/` - Business logic and use cases
  - `models/` - Data models and entities
  - `providers/` - Riverpod state providers
  - `repositories/` - Data abstraction layer
  - `screens/` - UI screens
  - `services/` - Business logic services
  - `utils/` - Utility functions
  - `widgets/` - Reusable UI components

## 🤝 Contributing

We welcome contributions! Please see our [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines on how to contribute to this project.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](./LICENSE) file for details.

## 🙏 Acknowledgments

- [Vosk ASR](https://alphacephei.com/vosk/) for providing excellent offline speech recognition
- The Flutter team for the amazing cross-platform framework
- All contributors who help improve AudioNotes