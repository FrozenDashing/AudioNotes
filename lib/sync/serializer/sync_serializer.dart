import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../../models/todo_item.dart';
import '../../models/category.dart';
import '../../models/tag.dart';
import 'todo_sync_dto.dart';

/// Serializer: converts between local models and JSON strings for WebDAV storage.
class SyncSerializer {
  /// Serialize a list of TodoSyncDto to JSON string
  String serializeTodos(List<TodoSyncDto> todos) {
    return jsonEncode(todos.map((e) => e.toJson()).toList());
  }

  /// Deserialize JSON string to a map of id -> TodoSyncDto
  Map<String, TodoSyncDto> deserializeTodos(String content) {
    final List jsonList = jsonDecode(content) as List;
    return {
      for (var e in jsonList)
        e['id'] as String: TodoSyncDto.fromJson(e as Map<String, dynamic>),
    };
  }

  /// Serialize a list of CategorySyncDto to JSON string
  String serializeCategories(List<CategorySyncDto> categories) {
    return jsonEncode(categories.map((e) => e.toJson()).toList());
  }

  /// Deserialize JSON string to a map of id -> CategorySyncDto
  Map<String, CategorySyncDto> deserializeCategories(String content) {
    final List jsonList = jsonDecode(content) as List;
    return {
      for (var e in jsonList)
        e['id'] as String: CategorySyncDto.fromJson(e as Map<String, dynamic>),
    };
  }

  /// Serialize a list of TagSyncDto to JSON string
  String serializeTags(List<TagSyncDto> tags) {
    return jsonEncode(tags.map((e) => e.toJson()).toList());
  }

  /// Deserialize JSON string to a map of id -> TagSyncDto
  Map<String, TagSyncDto> deserializeTags(String content) {
    final List jsonList = jsonDecode(content) as List;
    return {
      for (var e in jsonList)
        e['id'] as String: TagSyncDto.fromJson(e as Map<String, dynamic>),
    };
  }

  /// Serialize a list of ReminderSyncDto to JSON string
  String serializeReminders(List<ReminderSyncDto> reminders) {
    return jsonEncode(reminders.map((e) => e.toJson()).toList());
  }

  /// Deserialize JSON string to a map of id -> ReminderSyncDto
  Map<String, ReminderSyncDto> deserializeReminders(String content) {
    final List jsonList = jsonDecode(content) as List;
    return {
      for (var e in jsonList)
        e['id'] as String: ReminderSyncDto.fromJson(e as Map<String, dynamic>),
    };
  }

  /// Serialize SyncManifest to JSON string
  String serializeManifest(SyncManifest manifest) {
    return jsonEncode(manifest.toJson());
  }

  /// Deserialize JSON string to SyncManifest
  SyncManifest deserializeManifest(String content) {
    return SyncManifest.fromJson(jsonDecode(content) as Map<String, dynamic>);
  }

  /// Compute a hash for a string content (for change detection)
  String computeHash(String content) {
    return sha256.convert(utf8.encode(content)).toString();
  }

  /// Convert local TodoItem list to TodoSyncDto list
  List<TodoSyncDto> todosToDto(List<TodoItem> items,
      {Map<String, List<String>> tagIdsByTodo = const {}}) {
    return items
        .map((item) => TodoSyncDto.fromTodoItem(
              item,
              tagIds: tagIdsByTodo[item.id] ?? [],
            ))
        .toList();
  }

  /// Convert local Category list to CategorySyncDto list
  List<CategorySyncDto> categoriesToDto(List<Category> categories) {
    return categories.map((c) => CategorySyncDto.fromCategory(c)).toList();
  }

  /// Convert local Tag list to TagSyncDto list
  List<TagSyncDto> tagsToDto(List<Tag> tags) {
    return tags.map((t) => TagSyncDto.fromTag(t)).toList();
  }
}
