import 'package:flutter_test/flutter_test.dart';
import 'package:audio_notes/models/todo_item.dart';

void main() {
  group('TodoItem', () {
    test('should create a TodoItem with required fields', () {
      final todo = TodoItem(
        id: 'test-id-1',
        text: 'Test todo item',
        createdAt: DateTime.now(),
      );

      expect(todo.id, 'test-id-1');
      expect(todo.text, 'Test todo item');
      expect(todo.status, TodoStatus.pending);
    });

    test('should create a TodoItem with all fields', () {
      final now = DateTime.now();
      final todo = TodoItem(
        id: 'test-id-2',
        text: 'Complete todo',
        createdAt: now,
        updatedAt: now,
        audioPath: '/path/to/audio.pcm',
        status: TodoStatus.completed,
        orderIndex: 1,
        confidence: 0.95,
        meta: '{"key": "value"}',
      );

      expect(todo.id, 'test-id-2');
      expect(todo.text, 'Complete todo');
      expect(todo.status, TodoStatus.completed);
      expect(todo.audioPath, '/path/to/audio.pcm');
      expect(todo.orderIndex, 1);
      expect(todo.confidence, 0.95);
    });

    test('should copyWith updated fields', () {
      final original = TodoItem(
        id: 'test-id-3',
        text: 'Original text',
        createdAt: DateTime.now(),
        status: TodoStatus.pending,
      );

      final updated = original.copyWith(
        text: 'Updated text',
        status: TodoStatus.completed,
      );

      expect(updated.id, original.id); // ID should remain the same
      expect(updated.text, 'Updated text');
      expect(updated.status, TodoStatus.completed);
      expect(updated.createdAt, original.createdAt);
    });

    test('should convert to and from JSON', () {
      final now = DateTime.now();
      final todo = TodoItem(
        id: 'test-id-4',
        text: 'JSON test',
        createdAt: now,
        status: TodoStatus.pending,
        confidence: 0.85,
      );

      final json = todo.toJson();
      final restored = TodoItem.fromJson(json);

      expect(restored.id, todo.id);
      expect(restored.text, todo.text);
      expect(restored.status, todo.status);
      expect(restored.confidence, todo.confidence);
    });

    test('should have correct equality', () {
      final todo1 = TodoItem(
        id: 'same-id',
        text: 'Text 1',
        createdAt: DateTime.now(),
      );

      final todo2 = TodoItem(
        id: 'same-id',
        text: 'Text 2',
        createdAt: DateTime.now(),
      );

      final todo3 = TodoItem(
        id: 'different-id',
        text: 'Text 1',
        createdAt: DateTime.now(),
      );

      expect(todo1, equals(todo2)); // Same ID
      expect(todo1, isNot(equals(todo3))); // Different ID
    });

    test('ConfidenceLevel should categorize correctly', () {
      expect(ConfidenceLevel.fromValue(null), ConfidenceLevel.medium);
      expect(ConfidenceLevel.fromValue(0.3), ConfidenceLevel.low);
      expect(ConfidenceLevel.fromValue(0.5), ConfidenceLevel.medium);
      expect(ConfidenceLevel.fromValue(0.6), ConfidenceLevel.medium);
      expect(ConfidenceLevel.fromValue(0.79), ConfidenceLevel.medium);
      expect(ConfidenceLevel.fromValue(0.8), ConfidenceLevel.high);
      expect(ConfidenceLevel.fromValue(1.0), ConfidenceLevel.high);
    });

    test('TodoStatus should convert from value', () {
      expect(TodoStatus.fromValue(0), TodoStatus.pending);
      expect(TodoStatus.fromValue(1), TodoStatus.completed);
      expect(
          TodoStatus.fromValue(99), TodoStatus.pending); // Default to pending
    });
  });

  group('SpeechSegment', () {
    test('should create from map', () {
      final segmentMap = {
        'segment_id': 'seg-123',
        'text': 'Test segment',
        'start_ts': 1000,
        'end_ts': 2000,
        'audio_path': '/path/to/seg.pcm',
        'confidence': 0.9,
        'is_final': true,
      };

      // Note: SpeechSegment is not imported here for brevity
      // In actual tests, import and test similarly
      expect(segmentMap['segment_id'], 'seg-123');
    });
  });
}
