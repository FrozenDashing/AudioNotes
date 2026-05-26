# Changelog

All notable changes to AudioNotes will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial MVP release
- Flutter app with Riverpod state management
- SQLite database for todo persistence
- Platform channel interface for native ASR
- Android native plugin (Kotlin) with AudioRecord
- iOS native plugin (Swift) with AVAudioEngine
- Todo CRUD operations (create, read, update, delete)
- Drag-and-drop reordering of todos
- Real-time partial transcript display during recording
- VAD-based automatic sentence segmentation
- Confidence level indicators for recognition accuracy
- Edit dialog for modifying todo text
- Delete confirmation dialog
- Completion toggle with visual strikethrough
- Recording overlay with status indicator
- Empty state UI for new users
- Comprehensive README and setup documentation
- Unit tests for data models

### Planned
- Vosk ASR engine integration (currently simulated)
- Actual audio file recording and storage
- Re-record functionality implementation
- Floating recording widget for Android
- Home screen widget for iOS
- Export notes to text/markdown
- Search functionality
- Categories/tags for todos
- Cloud sync option
- Dark mode optimizations
- Accessibility improvements
- Integration tests
- Performance profiling and optimization

## [0.1.0] - 2026-05-25

### Initial MVP Release
- Project structure and architecture
- Core data models (TodoItem, SpeechSegment)
- Database layer with sqflite
- State management with Riverpod
- Main UI screens and widgets
- Native platform channel setup
- Basic Android and iOS plugins (stub implementations)
- Documentation and setup guides

---

## Version History

### Version Naming Convention

- **0.x.y** - Pre-release/MVP versions
- **1.x.y** - Stable releases
  - x = Major features or breaking changes
  - y = Bug fixes and minor improvements

### Release Process

1. Update version in `pubspec.yaml`
2. Update this CHANGELOG.md
3. Create git tag: `git tag -a v0.1.0 -m "Release v0.1.0"`
4. Push tag: `git push origin v0.1.0`
5. Build release artifacts
6. Distribute to testers/users
