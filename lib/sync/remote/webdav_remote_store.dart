import '../client/webdav_client_wrapper.dart';
import '../serializer/todo_sync_dto.dart';
import '../serializer/sync_serializer.dart';

/// Remote store: maps WebDAV files to/from DTO maps.
class WebDavRemoteStore {
  final WebDavClientWrapper _client;
  final SyncSerializer _serializer;

  static const String _manifestFile = 'manifest.json';
  static const String _todosFile = 'todos.json';
  static const String _categoriesFile = 'categories.json';
  static const String _tagsFile = 'tags.json';
  static const String _remindersFile = 'reminders.json';

  WebDavRemoteStore(this._client) : _serializer = SyncSerializer();

  /// Ensure the remote directory exists
  Future<void> ensureDir() async {
    await _client.ensureRemoteDir();
  }

  // ---- Manifest ----

  Future<SyncManifest?> loadManifest() async {
    final exists = await _client.fileExists(_manifestFile);
    if (!exists) return null;
    try {
      final content = await _client.downloadFile(_manifestFile);
      return _serializer.deserializeManifest(content);
    } catch (e) {
      throw StateError('Failed to load remote manifest: $e');
    }
  }

  Future<void> saveManifest(SyncManifest manifest) async {
    final content = _serializer.serializeManifest(manifest);
    await _client.uploadFile(_manifestFile, content);
  }

  // ---- Todos ----

  Future<Map<String, TodoSyncDto>> loadTodos() async {
    final exists = await _client.fileExists(_todosFile);
    if (!exists) return {};
    try {
      final content = await _client.downloadFile(_todosFile);
      return _serializer.deserializeTodos(content);
    } catch (e) {
      throw StateError('Failed to load remote todos: $e');
    }
  }

  Future<void> saveTodos(Map<String, TodoSyncDto> todos) async {
    final content = _serializer.serializeTodos(todos.values.toList());
    await _client.uploadFile(_todosFile, content);
  }

  // ---- Categories ----

  Future<Map<String, CategorySyncDto>> loadCategories() async {
    final exists = await _client.fileExists(_categoriesFile);
    if (!exists) return {};
    try {
      final content = await _client.downloadFile(_categoriesFile);
      return _serializer.deserializeCategories(content);
    } catch (e) {
      throw StateError('Failed to load remote categories: $e');
    }
  }

  Future<void> saveCategories(Map<String, CategorySyncDto> categories) async {
    final content = _serializer.serializeCategories(categories.values.toList());
    await _client.uploadFile(_categoriesFile, content);
  }

  // ---- Tags ----

  Future<Map<String, TagSyncDto>> loadTags() async {
    final exists = await _client.fileExists(_tagsFile);
    if (!exists) return {};
    try {
      final content = await _client.downloadFile(_tagsFile);
      return _serializer.deserializeTags(content);
    } catch (e) {
      throw StateError('Failed to load remote tags: $e');
    }
  }

  Future<void> saveTags(Map<String, TagSyncDto> tags) async {
    final content = _serializer.serializeTags(tags.values.toList());
    await _client.uploadFile(_tagsFile, content);
  }

  // ---- Reminders ----

  Future<Map<String, ReminderSyncDto>> loadReminders() async {
    final exists = await _client.fileExists(_remindersFile);
    if (!exists) return {};
    try {
      final content = await _client.downloadFile(_remindersFile);
      return _serializer.deserializeReminders(content);
    } catch (e) {
      throw StateError('Failed to load remote reminders: $e');
    }
  }

  Future<void> saveReminders(Map<String, ReminderSyncDto> reminders) async {
    final content = _serializer.serializeReminders(reminders.values.toList());
    await _client.uploadFile(_remindersFile, content);
  }

  /// Compute content hash for a given file (used for change detection)
  Future<String?> getFileHash(String filename) async {
    try {
      final exists = await _client.fileExists(filename);
      if (!exists) return null;
      final content = await _client.downloadFile(filename);
      return _serializer.computeHash(content);
    } catch (e) {
      return null;
    }
  }
}
