# AudioNotes Settings Feature Development Plan

## Overview
Based on the `settings-develop.md` requirements, we need to implement three new settings features:
1. **Model Switch** - Allow switching between offline speech recognition models
2. **Theme Color** - Allow customizing the app's theme colors
3. **Font Size** - Allow adjusting the app's font sizes

## Implementation Phases

### Phase 1: Data Models and State Management
- Create Settings model classes
- Set up Riverpod providers for settings state
- Implement persistent storage for settings

### Phase 2: Core Settings Functionality
- Implement model management features
- Implement theme color selection
- Implement font size adjustment

### Phase 3: UI Implementation
- Create settings screen UI
- Implement model selection screen
- Add preview areas for theme and font size

### Phase 4: Integration and Testing
- Integrate with existing app flow
- Test all features
- Verify persistence

## Technical Architecture

### Data Layer
- Settings model with fields: modelId, theme, fontScale, autoModelSelect
- Model metadata with: modelId, name, sizeBytes, version, downloadedAt, path, sha256, accuracyTag
- SharedPreferences for light preferences
- SQLite for model metadata

### State Management
- Riverpod providers for settings state
- SettingsNotifier to manage state changes
- SettingsRepository for data persistence

### UI Components
- Settings screen with sections for each feature
- Model selection screen with model cards
- Theme color picker with presets and custom option
- Font size slider with preview

## File Structure
```
lib/
├── models/
│   ├── settings.dart
│   └── model_metadata.dart
├── providers/
│   └── settings_provider.dart
├── repositories/
│   ├── settings_repository.dart
│   └── model_repository.dart
├── screens/
│   ├── settings_screen.dart
│   └── model_selection_screen.dart
├── widgets/
│   ├── theme_color_picker.dart
│   ├── font_size_slider.dart
│   └── model_card.dart
└── services/
    └── settings_service.dart
```

## Timeline
- Phase 1: 1 day
- Phase 2: 2 days
- Phase 3: 2 days
- Phase 4: 1 day
- Total: 6 days

## Risk Assessment
- Model download and management complexity
- Theme integration with existing UI
- Font scaling across all app components

## Next Steps
Begin with Phase 1: Creating data models and setting up state management.