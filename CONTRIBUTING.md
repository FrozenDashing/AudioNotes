# Contributing to AudioNotes

Thank you for your interest in contributing to AudioNotes! This document provides guidelines and instructions for contributing.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [How to Contribute](#how-to-contribute)
- [Development Workflow](#development-workflow)
- [Coding Standards](#coding-standards)
- [Testing](#testing)
- [Documentation](#documentation)
- [Pull Request Process](#pull-request-process)
- [Community](#community)

## Code of Conduct

Please read and follow our [Code of Conduct](CODE_OF_CONDUCT.md) to maintain a welcoming and inclusive community.

## Getting Started

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/AudioNotes.git
   cd AudioNotes
   ```
3. **Add upstream remote**:
   ```bash
   git remote add upstream https://github.com/ORIGINAL_OWNER/AudioNotes.git
   ```
4. **Set up the project** following [SETUP.md](SETUP.md)
5. **Create a branch** for your feature or fix

## How to Contribute

### Reporting Bugs

Before creating bug reports, check existing issues. When creating a bug report, include:

- **Clear title and description**
- **Steps to reproduce** the behavior
- **Expected vs actual behavior**
- **Screenshots** if applicable
- **Environment details**:
  - OS version (Android/iOS)
  - Flutter version
  - Device model
  - App version

**Example:**
```markdown
**Bug**: Recording crashes after 30 seconds on Android 12

**Steps to Reproduce:**
1. Open app on Pixel 6 with Android 12
2. Tap record button
3. Speak for 30+ seconds

**Expected:** Recording continues
**Actual:** App crashes with OutOfMemoryError

**Environment:**
- Device: Pixel 6
- OS: Android 12
- Flutter: 3.10.0
- App: 0.1.0
```

### Suggesting Features

Feature suggestions are welcome! Please provide:

- **Use case**: Why is this feature needed?
- **Proposed solution**: How should it work?
- **Alternatives considered**: Other approaches
- **Additional context**: Screenshots, mockups, etc.

### Your First Code Contribution

Look for issues labeled:
- `good first issue` - Perfect for beginners
- `help wanted` - Need community assistance
- `bug` - Fix existing issues

## Development Workflow

### 1. Create a Branch

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/issue-description
```

**Branch naming conventions:**
- `feature/description` - New features
- `fix/description` - Bug fixes
- `docs/description` - Documentation updates
- `refactor/description` - Code refactoring
- `test/description` - Adding tests

### 2. Make Changes

- Write clean, readable code
- Follow coding standards (see below)
- Add/update tests
- Update documentation

### 3. Commit Changes

```bash
git add .
git commit -m "type(scope): description"
```

**Commit message format** (Conventional Commits):
```
feat: add drag-and-drop reordering
fix: resolve audio recording crash on iOS
docs: update setup instructions
test: add unit tests for TodoItem model
refactor: simplify database queries
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation
- `style`: Formatting (no logic changes)
- `refactor`: Code restructuring
- `test`: Adding tests
- `chore`: Maintenance tasks

### 4. Sync with Upstream

```bash
git fetch upstream
git rebase upstream/main
```

### 5. Push and Create PR

```bash
git push origin feature/your-feature-name
```

Then open a Pull Request on GitHub.

## Coding Standards

### Dart/Flutter

- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart)
- Use `dart format` before committing
- Run `flutter analyze` and fix all issues
- Prefer `const` constructors where possible
- Use meaningful variable and function names
- Add comments for complex logic

**Example:**
```dart
// Good
Future<void> toggleCompletionStatus(String todoId) async {
  final todo = await _database.getTodo(todoId);
  if (todo == null) return;
  
  final newStatus = todo.status == TodoStatus.pending
      ? TodoStatus.completed
      : TodoStatus.pending;
      
  await _database.updateStatus(todoId, newStatus);
}

// Avoid
void toggle(String id) async {
  var t = await db.get(id);
  if (t != null) {
    await db.update(id, t.done ? 0 : 1);
  }
}
```

### Kotlin (Android)

- Follow [Kotlin coding conventions](https://kotlinlang.org/docs/coding-conventions.html)
- Use coroutines for async operations
- Handle exceptions properly
- Add null safety checks

### Swift (iOS)

- Follow [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
- Use optionals safely
- Follow ARC best practices
- Add proper error handling

### General Principles

- **DRY**: Don't Repeat Yourself
- **KISS**: Keep It Simple, Stupid
- **SOLID**: Follow SOLID principles
- **Single Responsibility**: One class/function, one purpose
- **Meaningful Names**: Clear, descriptive naming

## Testing

### Writing Tests

- Write tests for new features
- Maintain existing test coverage
- Test edge cases and error conditions
- Use descriptive test names

**Test structure:**
```dart
test('should create todo with valid data', () {
  // Arrange
  final todo = TodoItem(...);
  
  // Act
  final result = await database.insert(todo);
  
  // Assert
  expect(result.id, todo.id);
});
```

### Running Tests

```bash
# All tests
flutter test

# Specific test file
flutter test test/models/todo_item_test.dart

# With coverage
flutter test --coverage

# Integration tests
flutter test integration_test/
```

### Coverage Goal

Maintain ≥ 80% code coverage for core modules.

## Documentation

### Code Comments

- Document public APIs
- Explain complex algorithms
- Add TODO comments for future work
- Use dartdoc format

**Example:**
```dart
/// Calculates speech energy for VAD detection.
///
/// Uses RMS (Root Mean Square) method to determine
/// if audio segment contains speech or silence.
///
/// [samples] - Audio samples in PCM16 format
/// Returns energy level normalized to 0.0-1.0
double calculateEnergy(List<int> samples) {
  // Implementation
}
```

### README Updates

Update README.md when:
- Adding new features
- Changing setup process
- Modifying configuration
- Updating dependencies

## Pull Request Process

### Before Submitting

1. ✅ All tests pass
2. ✅ Code is formatted (`dart format .`)
3. ✅ No analyzer warnings (`flutter analyze`)
4. ✅ Documentation updated
5. ✅ CHANGELOG.md updated (if applicable)
6. ✅ Rebased on latest main

### PR Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Unit tests added/updated
- [ ] Integration tests added/updated
- [ ] Manually tested on Android
- [ ] Manually tested on iOS

## Screenshots (if applicable)
Add screenshots of UI changes

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex code
- [ ] Documentation updated
- [ ] No new warnings
```

### Review Process

1. **Automated Checks**: CI runs tests and linters
2. **Code Review**: Maintainers review code quality
3. **Feedback**: Address review comments
4. **Approval**: At least one maintainer approval required
5. **Merge**: Maintainer merges PR

### After Merge

- Delete your feature branch
- Sync with upstream:
  ```bash
  git checkout main
  git pull upstream main
  ```

## Community

### Communication Channels

- **GitHub Issues**: Bug reports and feature requests
- **GitHub Discussions**: Questions and ideas
- **Discord**: Real-time chat (link coming soon)
- **Email**: audionotes@example.com

### Recognition

Contributors are recognized in:
- CONTRIBUTORS.md file
- Release notes
- Project README

## Resources

- [Flutter Documentation](https://docs.flutter.dev/)
- [Dart Language Tour](https://dart.dev/guides/language/language-tour)
- [Riverpod Documentation](https://riverpod.dev/)
- [Vosk Documentation](https://alphacephei.com/vosk/)
- [Effective Dart](https://dart.dev/guides/language/effective-dart)

## Questions?

Don't hesitate to ask! Open an issue or reach out through any communication channel.

---

**Thank you for contributing to AudioNotes!** 🎉
