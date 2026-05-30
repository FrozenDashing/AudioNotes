import 'package:intl/intl.dart';
import 'todo_priority.dart';

/// Task lifecycle state (separate from completion status)
enum TodoTaskState {
  recording(0), // Currently recording
  recognizing(1), // Audio recorded, being recognized
  ready(2), // Recognition completed, ready to use
  failed(3); // Recognition failed

  final int value;
  const TodoTaskState(this.value);

  static TodoTaskState fromValue(int value) {
    return TodoTaskState.values.firstWhere(
      (state) => state.value == value,
      orElse: () => TodoTaskState.failed,
    );
  }
}

/// Status enum for todo items (completion status)
enum TodoStatus {
  pending(0),
  completed(1);

  final int value;
  const TodoStatus(this.value);

  static TodoStatus fromValue(int value) {
    return TodoStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => TodoStatus.pending,
    );
  }
}

/// Repeat frequency for scheduled todos
enum TodoRepeatType {
  none(0),
  daily(1),
  weekly(2);

  final int value;
  const TodoRepeatType(this.value);

  static TodoRepeatType fromValue(int value) {
    return TodoRepeatType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => TodoRepeatType.none,
    );
  }
}

/// Represents a single todo item generated from speech recognition
class TodoItem {
  final String id;
  final String text;
  final String? rawTranscript;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? audioPath;
  final TodoTaskState taskState; // Task lifecycle state
  final TodoStatus status; // Completion status
  final TodoPriority priority;
  final DateTime? dueAt;
  final DateTime? remindAt;
  final TodoRepeatType repeatType;
  final String? repeatRule;
  final String? categoryId;
  final bool pinned;
  final DateTime? completedAt;
  final DateTime? deletedAt;
  final String? errorMessage; // Error message if recognition failed
  final String? modelVersion; // Vosk model version used
  final int? orderIndex;
  final String? meta;
  final String? calendarEventId; // Calendar event ID for system calendar integration

  const TodoItem({
    required this.id,
    required this.text,
    this.rawTranscript,
    required this.createdAt,
    this.updatedAt,
    this.audioPath,
    this.taskState = TodoTaskState.ready,
    this.status = TodoStatus.pending,
    this.priority = TodoPriority.normal,
    this.dueAt,
    this.remindAt,
    this.repeatType = TodoRepeatType.none,
    this.repeatRule,
    this.categoryId,
    this.pinned = false,
    this.completedAt,
    this.deletedAt,
    this.errorMessage,
    this.modelVersion,
    this.orderIndex,
    this.meta,
  });

  /// Create TodoItem from database map
  factory TodoItem.fromJson(Map<String, dynamic> json) {
    return TodoItem(
      id: json['id'] as String,
      text: json['text'] as String,
      rawTranscript: json['raw_text'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
      updatedAt: json['updated_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['updated_at'] as int)
          : null,
      audioPath: json['audio_path'] as String?,
      taskState: TodoTaskState.fromValue(json['task_state'] as int? ?? 2),
      status: TodoStatus.fromValue(json['status'] as int? ?? 0),
      priority: TodoPriority.fromValue(json['priority'] as int?),
      dueAt: json['due_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['due_at'] as int)
          : null,
      remindAt: json['remind_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['remind_at'] as int)
          : null,
      repeatType: TodoRepeatType.fromValue(json['repeat_type'] as int? ?? 0),
      repeatRule: json['repeat_rule'] as String?,
      categoryId: json['category_id'] as String?,
      pinned: (json['pinned'] as int? ?? 0) == 1,
      completedAt: json['completed_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['completed_at'] as int)
          : null,
      deletedAt: json['deleted_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['deleted_at'] as int)
          : null,
      errorMessage: json['error_message'] as String?,
      modelVersion: json['model_version'] as String?,
      orderIndex: json['order_index'] as int?,
      meta: json['meta'] as String?,
    );
  }

  /// Convert TodoItem to database map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'raw_text': rawTranscript,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt?.millisecondsSinceEpoch,
      'audio_path': audioPath,
      'task_state': taskState.value,
      'status': status.value,
      'priority': priority.value,
      'due_at': dueAt?.millisecondsSinceEpoch,
      'remind_at': remindAt?.millisecondsSinceEpoch,
      'repeat_type': repeatType.value,
      'repeat_rule': repeatRule,
      'category_id': categoryId,
      'pinned': pinned ? 1 : 0,
      'completed_at': completedAt?.millisecondsSinceEpoch,
      'deleted_at': deletedAt?.millisecondsSinceEpoch,
      'error_message': errorMessage,
      'model_version': modelVersion,
      'order_index': orderIndex,
      'meta': meta,
    };
  }

  /// Create a new TodoItem with updated fields
  TodoItem copyWith({
    String? id,
    String? text,
    String? rawTranscript,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? audioPath,
    TodoTaskState? taskState,
    TodoStatus? status,
    TodoPriority? priority,
    DateTime? dueAt,
    DateTime? remindAt,
    TodoRepeatType? repeatType,
    String? repeatRule,
    String? categoryId,
    bool? pinned,
    DateTime? completedAt,
    DateTime? deletedAt,
    String? errorMessage,
    String? modelVersion,
    int? orderIndex,
    String? meta,
  }) {
    return TodoItem(
      id: id ?? this.id,
      text: text ?? this.text,
      rawTranscript: rawTranscript ?? this.rawTranscript,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      audioPath: audioPath ?? this.audioPath,
      taskState: taskState ?? this.taskState,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      dueAt: dueAt ?? this.dueAt,
      remindAt: remindAt ?? this.remindAt,
      repeatType: repeatType ?? this.repeatType,
      repeatRule: repeatRule ?? this.repeatRule,
      categoryId: categoryId ?? this.categoryId,
      pinned: pinned ?? this.pinned,
      completedAt: completedAt ?? this.completedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      errorMessage: errorMessage ?? this.errorMessage,
      modelVersion: modelVersion ?? this.modelVersion,
      orderIndex: orderIndex ?? this.orderIndex,
      meta: meta ?? this.meta,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TodoItem && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'TodoItem{id: $id, text: $text, status: $status, createdAt: $createdAt}';
  }

  /// Format the creation date for display
  String get formattedDate {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inDays == 0) {
      return 'Today at ${DateFormat('HH:mm').format(createdAt)}';
    } else if (difference.inDays == 1) {
      return 'Yesterday at ${DateFormat('HH:mm').format(createdAt)}';
    } else {
      return DateFormat('yyyy-MM-dd HH:mm').format(createdAt);
    }
  }
}
