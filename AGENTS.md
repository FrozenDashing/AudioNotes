# AudioNotes Agent Guidance

## Project Overview
AudioNotes is a Flutter mobile application that provides offline speech-to-text todo functionality using Vosk ASR engine. It follows Clean Architecture with Riverpod state management.

## Key Development Commands
```bash
# Install dependencies
flutter pub get

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

## Critical Setup Requirements
- **Vosk Models**: Must be downloaded separately from https://alphacephei.com/vosk/models and placed in `assets/models/`
- **Flutter SDK**: Requires Flutter SDK >= 3.0.0 and Dart SDK >= 3.0.0
- **Permissions**: Runtime permissions required for audio recording

## Project Structure
- `lib/` - Main application code organized in Clean Architecture layers:
  - `data/` - Database helpers and data sources
  - `domain/` - Business logic and use cases
  - `models/` - Data models
  - `providers/` - Riverpod state providers
  - `repositories/` - Data abstraction layer
  - `screens/` - UI screens
  - `services/` - Business logic services
  - `utils/` - Utility functions
  - `widgets/` - Reusable UI components

## Important Notes
- **Offline-First**: The app works completely offline using Vosk ASR
- **Audio Format**: Uses PCM16 for high-quality recordings
- **Category Grouping**: Todo items are organized into collapsible category groups
- **Model Management**: Supports multiple ASR models for different languages/accents

## Ignored Files
- Vosk models (too large for git): `assets/models/*.zip`, `assets/models/vosk-model-*`
- Audio recordings (user data): `**/audio/`, `*.pcm`, `*.wav`
- Build artifacts: `build/`, `ios/Flutter/`, `android/.gradle/`
- IDE configurations: `.idea/`, `.vscode/`, `*.iml`

## Testing
- Run `flutter test` to execute all tests
- Code quality analysis with `flutter analyze`
- Code formatting with `dart format .`

Always apply minimal changes to the code to meet up to the users' requirements.