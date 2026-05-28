# AudioNotes - Offline Speech-to-Text Todo Application

AudioNotes is an offline-first mobile application that converts speech into actionable todo items using Vosk Automatic Speech Recognition (ASR). Designed for productivity, it allows users to record thoughts hands-free and automatically generates organized todo lists without requiring internet connectivity. The application features category-based grouping, advanced todo management, and comprehensive organizational tools to maximize efficiency.

## 🚀 Features

### Core Functionality
- **Offline Speech Recognition**: Powered by Vosk ASR engine, works completely offline without internet dependency
- **Real-time Transcription**: Streams partial results as the user speaks for immediate feedback
- **Voice Activity Detection (VAD)**: Automatically segments sentences based on pauses for better organization
- **Smart Todo Creation**: Converts spoken thoughts into structured todo items with timestamps
- **Audio Playback**: Each todo includes the original audio recording for reference
- **Todo Management**: Create, edit, reorder, and complete tasks with intuitive UI

### Advanced Organization
- **Category Grouping**: Todo items organized into collapsible category groups (with "Uncategorized" for items without categories)
- **Flexible Tagging**: Multiple tags per todo for enhanced categorization
- **Priority Levels**: Low, Medium, High priority assignments
- **Deadline Management**: Set due dates for tasks
- **Reminder System**: Local notifications for timely task completion
- **Repeating Tasks**: Support for daily and weekly recurring tasks

### User Experience
- **Drag-and-Drop Interface**: Intuitive reordering of both categories and todos within categories
- **Collapsible Groups**: Expand/collapse category sections for focused viewing
- **Batch Operations**: Multi-select and bulk actions for efficient management
- **Visual Feedback**: Clear indicators for task status, priority, and deadlines
- **Responsive Design**: Optimized for various screen sizes and orientations

### Customization
- **Model Management**: Download, switch, and manage multiple ASR models for different languages/accents
- **Customizable Interface**: Adjust theme colors, font sizes, and UI elements to personal preference
- **Flexible Sorting**: Sort todos within categories by manual, creation date, due date, or priority
- **Personalized Settings**: Comprehensive settings for notification preferences, default priorities, and UI preferences

### Data & Storage
- **Persistent Storage**: All data stored locally using SQLite with audio files saved securely
- **Soft Deletion**: Todos marked as deleted but preserved for recovery
- **Confidence Tracking**: Recognition quality scores for accuracy assessment
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

AudioNotes follows Clean Architecture principles with three main layers, enhanced with a grouping service for category-based organization:

```
┌─────────────────┐    ┌─────────────────────┐    ┌──────────────────┐
│   Presentation  │───▶│     Domain          │───▶│      Data        │
│   (UI/Widgets)  │    │ (Business Logic)    │    │  (Repositories)  │
│                 │    │                     │    │                  │
│ • Screens       │    │ • Use Cases         │    │ • TodoRepo      │
│ • Widgets       │    │ • Entities          │    │ • ModelRepo     │
│ • Providers     │    │ • Grouping Service  │    │ • Database      │
└─────────────────┘    └─────────────────────┘    └──────────────────┘
```

### Key Components
- **UI Layer**: Flutter widgets and screens with Riverpod state management
- **Domain Layer**: Business rules, use cases, and grouping logic for category organization
- **Data Layer**: Local database, file system, and external service abstractions

## 📱 Usage

1. **Start Recording**: Tap the recording button to begin speaking
2. **Automatic Segmentation**: The app detects pauses to separate thoughts
3. **Real-time Transcription**: See partial results as you speak
4. **Todo Creation**: Completed segments automatically become todo items
5. **Category Organization**: Assign todos to categories or let uncategorized items go to the default group
6. **Manage Tasks**: Edit, complete, or play back original audio for each item
7. **Customize**: Adjust settings like theme, font size, model selection, and notification preferences

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

The project follows a Clean Architecture pattern with clear separation of concerns, enhanced with a category grouping service for the UI structure:

- `lib/` - Main application code
  - `data/` - Database helpers and data sources
  - `domain/` - Business logic and use cases
  - `models/` - Data models including TodoItem and TodoGroup
  - `providers/` - Riverpod state providers
  - `repositories/` - Data abstraction layer
  - `screens/` - UI screens
  - `services/` - Business logic services including todo grouping service
  - `utils/` - Utility functions
  - `widgets/` - Reusable UI components including TodoGroupSection

## 🤝 Contributing

We welcome contributions! Please see our [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines on how to contribute to this project.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](./LICENSE) file for details.

## 🙏 Acknowledgments

- [Vosk ASR](https://alphacephei.com/vosk/) for providing excellent offline speech recognition
- The Flutter team for the amazing cross-platform framework
- All contributors who help improve AudioNotes