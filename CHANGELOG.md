# Changelog

All notable changes to AudioNotes will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Category-based grouping view for todo items
- Todo grouping service to organize items by category
- Collapsible category sections with expand/collapse functionality
- Drag-and-drop reordering for both categories and todos within categories
- "Uncategorized" group for todos without assigned categories
- Priority management (low, medium, high)
- Deadline and reminder functionality with local notifications
- Tagging system for enhanced todo organization
- Repeating task support (daily, weekly)
- Soft deletion with deletedAt field
- Confidence scoring for recognition quality assessment
- Raw transcript storage alongside processed text
- Model management for Vosk ASR models with download capability
- Customizable settings for themes, font sizes, and preferences
- Audio playback functionality for recorded todo items
- Batch operations for multi-select and bulk actions
- Comprehensive SQLite schema with todos, categories, tags, and reminders tables
- Repository pattern implementation for data abstraction
- Riverpod state management for reactive UI updates
- Real-time partial transcript display during recording
- Voice activity detection (VAD) for automatic sentence segmentation
- Todo CRUD operations (create, read, update, delete)
- Drag-and-drop reordering of todos
- Confidence level indicators for recognition accuracy
- Edit dialog for modifying todo text
- Delete confirmation dialog
- Completion toggle with visual strikethrough
- Recording overlay with status indicator
- Empty state UI for new users
- Comprehensive README and setup documentation
- Unit tests for data models

### Changed
- Refactored database schema to support advanced features (due dates, reminders, categories, tags)
- Enhanced TodoItem model with priority, dueAt, remindAt, repeatType, categoryId, pinned, completedAt, deletedAt, orderIndex, confidence, and rawText fields
- Improved UI layout with category-based grouping structure
- Restructured data flow to support category grouping and two-tier sorting
- Enhanced state management with specialized providers for new features
- Optimized performance for large todo lists with virtual scrolling

### Fixed
- Audio recording and playback functionality
- Recognition accuracy and confidence scoring
- Database migration between schema versions
- UI responsiveness during large data operations
- Memory management during extended recording sessions
- Notification delivery reliability

### Removed
- Flat todo list view (replaced with category grouping)
- Global "sort by category" option (replaced with structural grouping)

## [0.2.0] - 2026-05-29

### Added
- Category-based grouping view implementation
- Todo grouping service for organizing items by category
- Collapsible category sections with visual indicators
- Drag-and-drop functionality for reordering categories
- "Uncategorized" group for unassigned todos
- Priority management system (low, medium, high)
- Deadline and reminder functionality
- Tagging system with multiple tags per todo
- Repeating task support (daily, weekly)
- Soft deletion with recovery capability
- Confidence scoring for recognition quality
- Raw transcript storage alongside processed text
- Enhanced database schema with additional tables

### Changed
- Updated database schema to version 5 with new fields and tables
- Restructured UI from flat list to hierarchical category groups
- Modified sorting behavior to support two-tier organization (categories and items within categories)
- Enhanced TodoItem model with additional fields for advanced features
- Improved error handling and user feedback mechanisms

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
- Basic todo CRUD operations
- Offline speech recognition with Vosk ASR
- Real-time transcription during recording
- Voice activity detection for sentence segmentation

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