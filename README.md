# AudioNotes - Offline Speech-to-Text Todo App

![Flutter](https://img.shields.io/badge/Flutter-3.0+-blue.svg)
![Dart](https://img.shields.io/badge/Dart-3.0+-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)

AudioNotes is an offline-first mobile application that converts speech to actionable todo items using Vosk ASR (Automatic Speech Recognition). Record your thoughts hands-free and automatically generate organized todo lists.

## Features

✅ **Offline Speech Recognition** - Powered by Vosk ASR, works without internet  
✅ **Real-time Transcription** - Stream partial results as you speak  
✅ **Voice Activity Detection** - Automatic sentence segmentation using VAD  
✅ **Todo Management** - Create, edit, reorder, and complete tasks  
✅ **Local Storage** - All data stored locally with SQLite  
✅ **Audio Recording** - Save original audio for each note  
✅ **Cross-platform** - Works on Android and iOS  

## Architecture

The app follows a clean architecture pattern with three main layers:

### 1. Flutter Layer (Dart)
- **UI**: Material Design 3 components with Riverpod state management
- **State Management**: Riverpod for reactive state
- **Business Logic**: Todo CRUD operations, recording control
- **Persistence**: SQLite database via sqflite

### 2. Native Plugin Layer
- **Android**: Kotlin implementation using AudioRecord + Vosk Android binding
- **iOS**: Swift implementation using AVAudioEngine + Vosk iOS binding
- **Platform Channel**: MethodChannel for Dart-native communication

### 3. Storage Layer
- **SQLite**: Structured todo item metadata
- **File System**: Audio recordings in PCM16 format (organized by date)

## Project Structure

```
AudioNotes/
├── lib/
│   ├── main.dart                 # App entry point
│   ├── models/
│   │   ├── todo_item.dart        # Todo data model
│   │   └── speech_segment.dart   # Speech recognition models
│   ├── data/
│   │   └── database_helper.dart  # SQLite database operations
│   ├── services/
│   │   └── asr_platform_service.dart  # Platform channel interface
│   ├── providers/
│   │   └── app_providers.dart    # Riverpod state providers
│   ├── screens/
│   │   └── home_screen.dart      # Main todo list screen
│   └── widgets/
│       ├── todo_item_card.dart   # Individual todo card
│       └── recording_overlay.dart # Recording UI overlay
├── android/
│   └── src/main/kotlin/
│       └── com/audionotes/audio_notes/
│           └── AsrPlugin.kt      # Android native plugin
├── ios/
│   └── Classes/
│       └── AsrPlugin.swift       # iOS native plugin
└── devlogs/
    └── stages/
        └── mvp.md                # MVP architecture document
```

## Getting Started

### Prerequisites

- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- Android Studio / Xcode for native development
- Vosk model files (download from [Vosk Models](https://alphacephei.com/vosk/models))

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd AudioNotes
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Generate code (JSON serialization)**
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

4. **Download Vosk model**
   - Download a small English model (e.g., `vosk-model-small-en-us-0.15`)
   - Place it in `assets/models/` directory
   - Update platform-specific code to load the model

5. **Run the app**
   ```bash
   flutter run
   ```

## Configuration

### Audio Settings

Default audio configuration:
- Sample Rate: 16000 Hz
- Channels: 1 (mono)
- Format: PCM16
- Frame Size: 3200 bytes (100ms)

### VAD Parameters

Configurable VAD thresholds:
- Short Pause: 600ms (triggers potential segment boundary)
- Long Pause: 1500ms (forces segment finalization)
- Energy Threshold: 0.3 (speech vs. silence detection)

### Database Schema

```sql
CREATE TABLE todo_item (
  id TEXT PRIMARY KEY,
  text TEXT NOT NULL,
  created_at INTEGER NOT NULL,
  updated_at INTEGER,
  audio_path TEXT,
  status INTEGER DEFAULT 0,
  order_index INTEGER,
  confidence REAL,
  meta TEXT
);
```

## Usage

### Recording Notes

1. Tap the **microphone button** to start recording
2. Speak clearly into the microphone
3. Partial transcripts appear in real-time
4. Pause naturally to trigger automatic segmentation
5. Tap **stop** to end recording session

### Managing Todos

- **Complete**: Tap the checkbox to mark as done
- **Edit**: Tap on a todo to modify text
- **Reorder**: Drag and drop using the handle icon
- **Delete**: Long press and select delete
- **Re-record**: Long press and select re-record (replaces audio and text)

### Performance Targets

- First partial transcript: ≤ 1.5 seconds
- Final segment processing: ≤ 0.5 seconds after silence
- CPU usage: ≤ 30% single core on mid-range devices
- Memory: < 200 MB with ASR model loaded

## Development

### Building for Production

**Android:**
```bash
flutter build apk --release
# or
flutter build appbundle --release
```

**iOS:**
```bash
flutter build ios --release
```

### Testing

Run all tests:
```bash
flutter test
```

Run integration tests:
```bash
flutter test integration_test/
```

### Code Quality

Analyze code:
```bash
flutter analyze
```

Format code:
```bash
dart format .
```

## Platform-Specific Notes

### Android

- Requires `RECORD_AUDIO` permission
- Uses `AudioRecord` for low-latency capture
- Foreground service recommended for long recordings
- Minimum API level: 21 (Android 5.0)

### iOS

- Requires `NSMicrophoneUsageDescription` in Info.plist
- Uses `AVAudioEngine` for audio capture
- Background audio mode must be enabled in capabilities
- Minimum iOS version: 12.0

## Roadmap

### Phase 0 - PoC (Completed)
- ✅ Basic project structure
- ✅ Platform channel setup
- ✅ Data models and database

### Phase 1 - Core Integration (In Progress)
- 🔄 Vosk ASR integration
- 🔄 Real-time streaming
- 🔄 VAD implementation

### Phase 2 - UX Enhancement (Planned)
- ⏳ Drag-and-drop reordering
- ⏳ Edit and re-record features
- ⏳ Confidence indicators

### Phase 3 - Advanced Features (Future)
- ⏳ Floating recording widget (Android)
- ⏳ Home screen widget (iOS)
- ⏳ Export to text/markdown
- ⏳ Cloud sync (optional)

## Troubleshooting

### Microphone Permission Issues

**Android:**
- Ensure `RECORD_AUDIO` permission is granted
- Check runtime permissions in app settings

**iOS:**
- Verify `NSMicrophoneUsageDescription` in Info.plist
- Enable microphone in Privacy settings

### Recognition Accuracy

- Use high-quality Vosk models for better accuracy
- Speak clearly in quiet environments
- Adjust VAD energy threshold for noisy environments
- Consider noise cancellation preprocessing

### Performance Issues

- Reduce frame size for lower latency (increases CPU)
- Use smaller Vosk models for faster loading
- Enable WAL mode in SQLite for better write performance
- Profile with Flutter DevTools

## Contributing

Contributions are welcome! Please read our contributing guidelines and submit pull requests.

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Vosk](https://alphacephei.com/vosk/) - Offline speech recognition toolkit
- [Flutter](https://flutter.dev/) - UI framework
- [Riverpod](https://riverpod.dev/) - State management
- [sqflite](https://pub.dev/packages/sqflite) - SQLite plugin

## Support

For issues, questions, or contributions:
- Open an issue on GitHub
- Email: 251250073@smail.nju.edu.cn
---

**Built with ❤️ for productivity enthusiasts**
