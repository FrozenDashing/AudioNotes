# Quick Start Guide - AudioNotes

This guide will help you quickly set up and run the AudioNotes project on your local machine.

## Prerequisites

- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- Android Studio (for Android development) or Xcode (for iOS development)
- Git
- Vosk ASR models (download separately from https://alphacephei.com/vosk/models)

## Setup Instructions

### 1. Clone the Repository
```bash
git clone <repository-url>
cd AudioNotes
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Generate Code (if needed)
If you make changes to JSON serializable classes, run:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 4. Setup Vosk ASR Models
AudioNotes uses offline Vosk ASR models for speech recognition. You need to download and place the models in the appropriate directory:
- Download Vosk model (e.g., `vosk-model-small-en-us-0.15`)
- Place in `assets/models/` directory (create if it doesn't exist)

### 5. Run the Application
```bash
# For Android/iOS device or emulator
flutter run

# For specific platform
flutter run -d android
flutter run -d ios
```

## Development Commands

### Testing
```bash
# Run unit tests
flutter test

# Run all tests
flutter test --coverage
```

### Code Quality
```bash
# Analyze code
flutter analyze

# Format code
dart format .

# Fix formatting issues
dart fix --dry-run
dart fix --apply
```

### Building for Production
```bash
# Build Android APK
flutter build apk --release

# Build Android App Bundle
flutter build appbundle --release

# Build iOS
flutter build ios --release
```

## Troubleshooting

### Kotlin Cache Errors
If you encounter Kotlin incremental compilation errors:
1. Run `flutter clean`
2. Manually delete `build`, `android/build`, `android/app/build` directories
3. Check that `kotlin.incremental=false` is set in `android/gradle.properties`
4. Run `flutter pub get` again

### Missing Dependencies
If you see missing package errors:
1. Verify Flutter is installed and in PATH
2. Run `flutter pub get` again
3. Check your internet connection
4. Try running `flutter doctor` to diagnose issues

## Next Steps
- Review [README.md](./README.md) for project overview
- Check [ARCHITECTURE.md](./ARCHITECTURE.md) for technical details
- Look at [PROJECT_STRUCTURE.md](./PROJECT_STRUCTURE.md) for file organization