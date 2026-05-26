# AudioNotes - Quick Reference Guide

## Common Commands

### Development
```bash
# Install dependencies
flutter pub get

# Generate code (after model changes)
dart run build_runner build --delete-conflicting-outputs

# Run app
flutter run

# Hot reload: Press 'r' in terminal
# Hot restart: Press 'R' in terminal
# Quit: Press 'q' in terminal
```

### Testing
```bash
# Run all tests
flutter test

# Run specific test
flutter test test/models/todo_item_test.dart

# Test with coverage
flutter test --coverage
```

### Code Quality
```bash
# Analyze code
flutter analyze

# Format all Dart files
dart format .

# Fix auto-fixable issues
dart fix --apply
```

### Building
```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS
flutter build ios --release
```

### Cleanup
```bash
# Clean build artifacts
flutter clean

# Rebuild from scratch
flutter clean && flutter pub get && flutter run
```

## Key Files to Modify

### Adding New Features
1. **Data Model**: `lib/models/your_model.dart`
2. **Database**: `lib/data/database_helper.dart`
3. **State Provider**: `lib/providers/app_providers.dart`
4. **UI Screen**: `lib/screens/your_screen.dart`
5. **UI Widget**: `lib/widgets/your_widget.dart`

### Platform-Specific Changes
- **Android**: `android/src/main/kotlin/com/audionotes/audio_notes/AsrPlugin.kt`
- **iOS**: `ios/Classes/AsrPlugin.swift`

### Configuration
- **Dependencies**: `pubspec.yaml`
- **Permissions Android**: `android/src/main/AndroidManifest.xml`
- **Permissions iOS**: `ios/Runner/Info.plist`

## Architecture Patterns

### State Management (Riverpod)
```dart
// Define provider
final myProvider = StateNotifierProvider<MyNotifier, MyState>((ref) {
  return MyNotifier();
});

// Read state
final state = ref.watch(myProvider);

// Update state
ref.read(myProvider.notifier).updateMethod();
```

### Database Operations
```dart
// Get instance
final dbHelper = ref.read(databaseHelperProvider);

// Insert
await dbHelper.insertTodo(todoItem);

// Query
final todos = await dbHelper.getAllTodos();

// Update
await dbHelper.updateTodo(todoItem);

// Delete
await dbHelper.deleteTodo(id);
```

### Platform Channel Usage
```dart
// Get service
final asrService = ref.read(asrPlatformServiceProvider);

// Start recording
await asrService.startRecording(AudioConfig());

// Listen to events
asrService.finalSegmentStream.listen((segment) {
  // Handle segment
});
```

## Data Models Quick Reference

### TodoItem
```dart
TodoItem(
  id: String,              // UUID
  text: String,            // Note content
  createdAt: DateTime,     // Creation timestamp
  updatedAt: DateTime?,    // Last update timestamp
  audioPath: String?,      // Path to audio file
  status: TodoStatus,      // pending | completed
  orderIndex: int?,        // Manual sort order
  confidence: double?,     // ASR confidence (0-1)
  meta: String?,           // JSON metadata
)
```

### SpeechSegment
```dart
SpeechSegment(
  segmentId: String,       // UUID
  text: String,            // Recognized text
  startTimestamp: int,     // Start time (ms)
  endTimestamp: int,       // End time (ms)
  audioPath: String,       // Audio file path
  confidence: double?,     // Confidence score
  isFinal: bool,           // Is finalized
)
```

## VAD Configuration

```dart
VADConfig(
  shortPauseMs: 600,       // Short pause threshold
  longPauseMs: 1500,       // Long pause (forces segment)
  energyThreshold: 0.3,    // Speech detection sensitivity
)
```

## Audio Configuration

```dart
AudioConfig(
  sampleRate: 16000,       // Hz
  channels: 1,             // Mono
  format: 'pcm16',         // 16-bit PCM
)
```

## Debugging Tips

### Flutter DevTools
```bash
# Launch DevTools
flutter pub global run devtools

# Opens browser at http://127.0.0.1:9100
```

### Logging
```dart
// Add logging
import 'package:flutter/foundation.dart';

if (kDebugMode) {
  print('Debug info: $value');
}
```

### Platform Channel Debugging
```dart
// Log platform calls
print('Calling native: ${call.method}');
print('Arguments: ${call.arguments}');
```

### Database Inspection
```bash
# Android: Pull database file
adb shell run-as com.audionotes.audio_notes cp /data/data/com.audionotes.audio_notes/databases/audionotes.db /sdcard/

# iOS: Use Xcode Devices window to download container
```

## Common Issues & Solutions

### Issue: "No devices found"
```bash
# Check device connection
flutter devices

# Enable USB debugging (Android)
# Trust computer (iOS)
```

### Issue: Build fails after dependency update
```bash
flutter clean
flutter pub get
flutter run
```

### Issue: Permission denied
```dart
// Request permission at runtime
final status = await Permission.microphone.request();
if (status.isGranted) {
  // Proceed
}
```

### Issue: Hot reload not working
```bash
# Try hot restart (capital R)
# Or rebuild completely
flutter clean && flutter run
```

### Issue: Platform channel error
- Check method name matches on both sides
- Verify arguments type matches
- Ensure plugin is registered

## Git Workflow

```bash
# Create feature branch
git checkout -b feature/my-feature

# Commit changes
git add .
git commit -m "feat: add new feature"

# Sync with upstream
git fetch upstream
git rebase upstream/main

# Push to fork
git push origin feature/my-feature

# Create PR on GitHub
```

## Release Checklist

```
□ Update version in pubspec.yaml
□ Update CHANGELOG.md
□ Run flutter test
□ Run flutter analyze
□ dart format .
□ Test on Android device
□ Test on iOS device
□ Build release APK
□ Build release IPA
□ Create git tag
□ Push to repository
```

## Useful Links

- [Flutter Docs](https://docs.flutter.dev/)
- [Riverpod Docs](https://riverpod.dev/)
- [Dart Packages](https://pub.dev/)
- [Vosk Docs](https://alphacephei.com/vosk/)
- [Material Design 3](https://m3.material.io/)

## Keyboard Shortcuts (VS Code)

| Action | Shortcut |
|--------|----------|
| Hot Reload | Ctrl+S (auto-save) |
| Hot Restart | Ctrl+Shift+F5 |
| Run App | F5 |
| Stop Debugging | Shift+F5 |
| Toggle Breakpoint | F9 |
| Step Over | F10 |
| Step Into | F11 |

## Environment Variables

Create `.env` file (not committed):
```env
# Not currently used, reserved for future
API_KEY=your_api_key
ANALYTICS_ID=your_id
```

## Performance Monitoring

```dart
// Measure execution time
final stopwatch = Stopwatch()..start();
// ... operation ...
stopwatch.stop();
print('Time: ${stopwatch.elapsedMilliseconds}ms');

// Profile widget builds
@override
Widget build(BuildContext context) {
  print('Building ${runtimeType}');
  return Container();
}
```

---

**Keep this guide handy for quick reference!** 📚

*Last updated: 2026-05-25*
