import 'package:intl/intl.dart';

/// Task lifecycle state (separate from completion status)
enum TodoTaskState {
  recording(0),    // Currently recording
  recognizing(1),  // Audio recorded, being recognized
  ready(2),        // Recognition completed, ready to use
  failed(3);       // Recognition failed

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

/// Confidence level for ASR results
enum ConfidenceLevel {
  low(0),
  medium(1),
  high(2);

  final int value;
  const ConfidenceLevel(this.value);
  
  static ConfidenceLevel fromValue(double? confidence) {
    if (confidence == null) return ConfidenceLevel.medium;
    if (confidence < 0.5) return ConfidenceLevel.low;
    if (confidence < 0.8) return ConfidenceLevel.medium;
    return ConfidenceLevel.high;
  }
}

/// Represents a single todo item generated from speech recognition
class TodoItem {
  final String id;
  final String text;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? audioPath;
  final TodoTaskState taskState;  // Task lifecycle state
  final TodoStatus status;        // Completion status
  final int? durationMs;          // Audio duration in milliseconds
  final String? errorMessage;     // Error message if recognition failed
  final String? modelVersion;     // Vosk model version used
  final int? orderIndex;
  final double? confidence;
  final String? meta;

  const TodoItem({
    required this.id,
    required this.text,
    required this.createdAt,
    this.updatedAt,
    this.audioPath,
    this.taskState = TodoTaskState.ready,
    this.status = TodoStatus.pending,
    this.durationMs,
    this.errorMessage,
    this.modelVersion,
    this.orderIndex,
    this.confidence,
    this.meta,
  });

  /// Create TodoItem from database map
  factory TodoItem.fromJson(Map<String, dynamic> json) {
    return TodoItem(
      id: json['id'] as String,
      text: json['text'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
      updatedAt: json['updated_at'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(json['updated_at'] as int)
          : null,
      audioPath: json['audio_path'] as String?,
      taskState: TodoTaskState.fromValue(json['task_state'] as int? ?? 2),
      status: TodoStatus.fromValue(json['status'] as int? ?? 0),
      durationMs: json['duration_ms'] as int?,
      errorMessage: json['error_message'] as String?,
      modelVersion: json['model_version'] as String?,
      orderIndex: json['order_index'] as int?,
      confidence: json['confidence'] as double?,
      meta: json['meta'] as String?,
    );
  }
  
  /// Convert TodoItem to database map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt?.millisecondsSinceEpoch,
      'audio_path': audioPath,
      'task_state': taskState.value,
      'status': status.value,
      'duration_ms': durationMs,
      'error_message': errorMessage,
      'model_version': modelVersion,
      'order_index': orderIndex,
      'confidence': confidence,
      'meta': meta,
    };
  }

  /// Create a new TodoItem with updated fields
  TodoItem copyWith({
    String? id,
    String? text,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? audioPath,
    TodoTaskState? taskState,
    TodoStatus? status,
    int? durationMs,
    String? errorMessage,
    String? modelVersion,
    int? orderIndex,
    double? confidence,
    String? meta,
  }) {
    return TodoItem(
      id: id ?? this.id,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      audioPath: audioPath ?? this.audioPath,
      taskState: taskState ?? this.taskState,
      status: status ?? this.status,
      durationMs: durationMs ?? this.durationMs,
      errorMessage: errorMessage ?? this.errorMessage,
      modelVersion: modelVersion ?? this.modelVersion,
      orderIndex: orderIndex ?? this.orderIndex,
      confidence: confidence ?? this.confidence,
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
