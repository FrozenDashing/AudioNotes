# AudioNotes Setup Guide

This guide helps you set up the AudioNotes project for development.

## Quick Start

### 1. Install Flutter

If you haven't installed Flutter yet:

```bash
# Download from https://flutter.dev/docs/get-started/install
# Or use package manager:

# macOS
brew install --cask flutter

# Windows (using Chocolatey)
choco install flutter

# Linux
sudo snap install flutter --classic
```

Verify installation:
```bash
flutter doctor
```

### 2. Clone and Setup

```bash
# Navigate to project directory
cd AudioNotes

# Install dependencies
flutter pub get

# Generate code (JSON serialization)
dart run build_runner build --delete-conflicting-outputs
```

### 3. Download Vosk Model

The app requires a Vosk speech recognition model:

```bash
# Create models directory
mkdir -p assets/models

# Download small English model (recommended for MVP)
# Option 1: Manual download
# Visit: https://alphacephei.com/vosk/models
# Download: vosk-model-small-en-us-0.15.zip
# Extract to: assets/models/vosk-model-small-en-us-0.15

# Option 2: Using curl (Linux/macOS)
curl -L https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip -o assets/models/model.zip
unzip assets/models/model.zip -d assets/models/
rm assets/models/model.zip
```

**Model Options:**
- `vosk-model-small-en-us-0.15` (~40 MB) - Fast, good for mobile
- `vosk-model-en-us-0.22` (~1.8 GB) - Higher accuracy, slower
- `vosk-model-en-in-0.4` (~600 MB) - Indian English variant

### 4. Platform Setup

#### Android

1. Open `android/` in Android Studio
2. Install required SDK components:
   - Android SDK Platform 33+ (Android 13)
   - Android SDK Build-Tools
   - NDK (for native code compilation)

3. Update `android/local.properties`:
   ```properties
   sdk.dir=/path/to/your/android/sdk
   ```

4. Add Vosk dependency to `android/build.gradle`:
   ```gradle
   dependencies {
       implementation 'com.alphacephei:vosk-android:0.3.45'
       implementation 'net.java.dev.jna:jna:5.13.0@aar'
   }
   ```

#### iOS

1. Open `ios/Runner.xcworkspace` in Xcode
2. Set minimum deployment target to iOS 12.0 or higher
3. Enable microphone capability:
   - Go to Runner target → Signing & Capabilities
   - Add "Background Modes" capability
   - Check "Audio, AirPlay, and Picture in Picture"

4. Add Vosk framework:
   ```bash
   # Using CocoaPods (recommended)
   cd ios
   pod init
   
   # Edit Podfile and add:
   # pod 'Vosk', '~> 0.3.45'
   
   pod install
   ```

### 5. Configure Permissions

#### Android Permissions

Already configured in `android/src/main/AndroidManifest.xml`:
- `RECORD_AUDIO`
- `WRITE_EXTERNAL_STORAGE`
- `READ_EXTERNAL_STORAGE`

#### iOS Permissions

Already configured in `ios/Runner/Info.plist`:
- `NSMicrophoneUsageDescription`

### 6. Run the App

```bash
# Run on connected device or emulator
flutter run

# Run in release mode
flutter run --release

# Run on specific device
flutter devices  # List available devices
flutter run -d <device-id>
```

## Development Workflow

### Hot Reload

During development, use hot reload for quick iterations:
```bash
# Press 'r' in the terminal while app is running
# Or save a file (if using VS Code with auto-save)
```

### Debugging

1. **Flutter DevTools**
   ```bash
   flutter pub global activate devtools
   flutter pub global run devtools
   ```
   Then open the URL shown and connect to your running app.

2. **Platform-Specific Debugging**
   - Android: Use Android Studio debugger for Kotlin code
   - iOS: Use Xcode debugger for Swift code

### Testing

```bash
# Run unit tests
flutter test

# Run with coverage
flutter test --coverage

# View coverage report
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Building for Production

```bash
# Android APK
flutter build apk --release

# Android App Bundle (for Play Store)
flutter build appbundle --release

# iOS
flutter build ios --release
# Then archive in Xcode for App Store submission
```

## Troubleshooting

### Common Issues

#### "No devices found"
```bash
# Check connected devices
flutter devices

# For Android, enable USB debugging
# For iOS, trust the computer and enable developer mode
```

#### "Permission denied" errors

**Android:**
```bash
# Grant permissions manually in app settings
# Or request at runtime (already implemented)
```

**iOS:**
```bash
# Reset permissions
# Settings → General → Reset → Reset Location & Privacy
```

#### Build failures

**Clean and rebuild:**
```bash
flutter clean
flutter pub get
flutter run
```

**Android specific:**
```bash
cd android
./gradlew clean
cd ..
flutter run
```

**iOS specific:**
```bash
cd ios
pod deintegrate
pod install
cd ..
flutter run
```

#### Vosk model not loading

1. Verify model is in correct location:
   ```bash
   ls assets/models/vosk-model-small-en-us-0.15
   ```

2. Check platform-specific loading code in:
   - `android/src/main/kotlin/.../AsrPlugin.kt`
   - `ios/Classes/AsrPlugin.swift`

3. Ensure model path is absolute and accessible

### Performance Optimization

1. **Use smaller models** for faster loading
2. **Enable ProGuard/R8** for Android release builds
3. **Optimize audio buffer size** based on device capabilities
4. **Profile with DevTools** to identify bottlenecks

## Next Steps

After successful setup:

1. ✅ Test basic recording functionality
2. ✅ Verify speech recognition works
3. ✅ Test todo creation and management
4. ✅ Try reordering todos
5. ✅ Test edit and delete features
6. ✅ Verify data persistence after app restart

## Getting Help

- 📖 [README.md](README.md) - Full documentation
- 🐛 [GitHub Issues](link-to-issues) - Report bugs
- 💬 [Discussions](link-to-discussions) - Ask questions
- 📧 Email: support@audionotes.com

## Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Riverpod Documentation](https://riverpod.dev/)
- [Vosk Documentation](https://alphacephei.com/vosk/)
- [sqflite Documentation](https://pub.dev/packages/sqflite)

---

Happy coding! 🚀
