import '../../models/todo_item.dart';
import '../../models/todo_priority.dart';
import '../../models/category.dart';
import '../../models/tag.dart';

/// Sync DTO for TodoItem – only includes fields relevant for cloud sync.
class TodoSyncDto {
  final String id;
  final String text;
  final String? rawTranscript;
  final int createdAt;
  final int? updatedAt;
  final int taskState;
  final int status;
  final int priority;
  final int? dueAt;
  final int? remindAt;
  final int repeatType;
  final String? repeatRule;
  final String? categoryId;
  final bool pinned;
  final int? completedAt;
  final int? deletedAt;
  final int? orderIndex;
  final List<String> tagIds;

  const TodoSyncDto({
    required this.id,
    required this.text,
    this.rawTranscript,
    required this.createdAt,
    this.updatedAt,
    this.taskState = 2,
    this.status = 0,
    this.priority = 1,
    this.dueAt,
    this.remindAt,
    this.repeatType = 0,
    this.repeatRule,
    this.categoryId,
    this.pinned = false,
    this.completedAt,
    this.deletedAt,
    this.orderIndex,
    this.tagIds = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'rawTranscript': rawTranscript,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'taskState': taskState,
        'status': status,
        'priority': priority,
        'dueAt': dueAt,
        'remindAt': remindAt,
        'repeatType': repeatType,
        'repeatRule': repeatRule,
        'categoryId': categoryId,
        'pinned': pinned,
        'completedAt': completedAt,
        'deletedAt': deletedAt,
        'orderIndex': orderIndex,
        'tagIds': tagIds,
      };

  static TodoSyncDto fromJson(Map<String, dynamic> json) => TodoSyncDto(
        id: json['id'] as String,
        text: json['text'] as String,
        rawTranscript: json['rawTranscript'] as String?,
        createdAt: json['createdAt'] as int,
        updatedAt: json['updatedAt'] as int?,
        taskState: json['taskState'] as int? ?? 2,
        status: json['status'] as int? ?? 0,
        priority: json['priority'] as int? ?? 1,
        dueAt: json['dueAt'] as int?,
        remindAt: json['remindAt'] as int?,
        repeatType: json['repeatType'] as int? ?? 0,
        repeatRule: json['repeatRule'] as String?,
        categoryId: json['categoryId'] as String?,
        pinned: json['pinned'] as bool? ?? false,
        completedAt: json['completedAt'] as int?,
        deletedAt: json['deletedAt'] as int?,
        orderIndex: json['orderIndex'] as int?,
        tagIds: List<String>.from(json['tagIds'] as List? ?? []),
      );

  /// Convert from local TodoItem (+ its tag IDs)
  factory TodoSyncDto.fromTodoItem(TodoItem item,
      {List<String> tagIds = const []}) {
    return TodoSyncDto(
      id: item.id,
      text: item.text,
      rawTranscript: item.rawTranscript,
      createdAt: item.createdAt.millisecondsSinceEpoch,
      updatedAt: item.updatedAt?.millisecondsSinceEpoch,
      taskState: item.taskState.value,
      status: item.status.value,
      priority: item.priority.value,
      dueAt: item.dueAt?.millisecondsSinceEpoch,
      remindAt: item.remindAt?.millisecondsSinceEpoch,
      repeatType: item.repeatType.value,
      repeatRule: item.repeatRule,
      categoryId: item.categoryId,
      pinned: item.pinned,
      completedAt: item.completedAt?.millisecondsSinceEpoch,
      deletedAt: item.deletedAt?.millisecondsSinceEpoch,
      orderIndex: item.orderIndex,
      tagIds: tagIds,
    );
  }

  /// Convert back to local TodoItem (audioPath & other local-only fields are omitted)
  TodoItem toTodoItem() {
    return TodoItem(
      id: id,
      text: text,
      rawTranscript: rawTranscript,
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
      updatedAt: updatedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(updatedAt!)
          : null,
      taskState: TodoTaskState.fromValue(taskState),
      status: TodoStatus.fromValue(status),
      priority: TodoPriority.fromValue(priority),
      dueAt: dueAt != null ? DateTime.fromMillisecondsSinceEpoch(dueAt!) : null,
      remindAt: remindAt != null
          ? DateTime.fromMillisecondsSinceEpoch(remindAt!)
          : null,
      repeatType: TodoRepeatType.fromValue(repeatType),
      repeatRule: repeatRule,
      categoryId: categoryId,
      pinned: pinned,
      completedAt: completedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(completedAt!)
          : null,
      deletedAt: deletedAt != null
          ? DateTime.fromMillisecondsSinceEpoch(deletedAt!)
          : null,
      orderIndex: orderIndex,
    );
  }
}

/// Sync DTO for Category
class CategorySyncDto {
  final String id;
  final String name;
  final int? color;
  final int sortOrder;
  final bool isHidden;

  const CategorySyncDto({
    required this.id,
    required this.name,
    this.color,
    this.sortOrder = 0,
    this.isHidden = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color,
        'sortOrder': sortOrder,
        'isHidden': isHidden,
      };

  static CategorySyncDto fromJson(Map<String, dynamic> json) => CategorySyncDto(
        id: json['id'] as String,
        name: json['name'] as String,
        color: json['color'] as int?,
        sortOrder: json['sortOrder'] as int? ?? 0,
        isHidden: json['isHidden'] as bool? ?? false,
      );

  factory CategorySyncDto.fromCategory(Category c) => CategorySyncDto(
        id: c.id,
        name: c.name,
        color: c.color,
        sortOrder: c.sortOrder,
        isHidden: c.isHidden,
      );

  Category toCategory() => Category(
        id: id,
        name: name,
        color: color,
        sortOrder: sortOrder,
        isHidden: isHidden,
      );
}

/// Sync DTO for Tag
class TagSyncDto {
  final String id;
  final String name;
  final int? color;

  const TagSyncDto({
    required this.id,
    required this.name,
    this.color,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'color': color,
      };

  static TagSyncDto fromJson(Map<String, dynamic> json) => TagSyncDto(
        id: json['id'] as String,
        name: json['name'] as String,
        color: json['color'] as int?,
      );

  factory TagSyncDto.fromTag(Tag t) => TagSyncDto(
        id: t.id,
        name: t.name,
        color: t.color,
      );

  Tag toTag() => Tag(
        id: id,
        name: name,
        color: color,
      );
}

/// Sync DTO for Reminder
class ReminderSyncDto {
  final String id;
  final String todoId;
  final int notificationId;
  final int remindAt;
  final int fired;

  const ReminderSyncDto({
    required this.id,
    required this.todoId,
    required this.notificationId,
    required this.remindAt,
    this.fired = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'todoId': todoId,
        'notificationId': notificationId,
        'remindAt': remindAt,
        'fired': fired,
      };

  static ReminderSyncDto fromJson(Map<String, dynamic> json) => ReminderSyncDto(
        id: json['id'] as String,
        todoId: json['todoId'] as String,
        notificationId: json['notificationId'] as int,
        remindAt: json['remindAt'] as int,
        fired: json['fired'] as int? ?? 0,
      );

  factory ReminderSyncDto.fromMap(Map<String, dynamic> map) => ReminderSyncDto(
        id: map['id'] as String,
        todoId: map['todo_id'] as String,
        notificationId: map['notification_id'] as int,
        remindAt: map['remind_at'] as int,
        fired: map['fired'] as int? ?? 0,
      );
}

/// Manifest file stored on WebDAV to track sync state
class SyncManifest {
  final String version;
  final int? lastSyncedAt;
  final Map<String, String> fileHashes; // filename -> hash

  const SyncManifest({
    this.version = '1',
    this.lastSyncedAt,
    this.fileHashes = const {},
  });

  Map<String, dynamic> toJson() => {
        'version': version,
        'lastSyncedAt': lastSyncedAt,
        'fileHashes': fileHashes,
      };

  static SyncManifest fromJson(Map<String, dynamic> json) => SyncManifest(
        version: json['version'] as String? ?? '1',
        lastSyncedAt: json['lastSyncedAt'] as int?,
        fileHashes: Map<String, String>.from(json['fileHashes'] as Map? ?? {}),
      );
}
