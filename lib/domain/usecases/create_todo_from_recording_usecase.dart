import 'package:flutter/foundation.dart' as foundation;

import '../../services/recognition_service.dart';
import '../../data/todo_repository.dart';
import '../../repositories/settings_repository.dart';
import '../../models/todo_item.dart';

/// Use case that handles recognition and post-processing for recorded audio
class CreateTodoFromRecordingUseCase {
  final RecognitionService _recognition;
  final TodoRepository _repository;
  final SettingsRepository _settingsRepository;

  CreateTodoFromRecordingUseCase({
    required RecognitionService recognition,
    required TodoRepository repository,
    required SettingsRepository settingsRepository,
  })  : _recognition = recognition,
        _repository = repository,
        _settingsRepository = settingsRepository;

  /// Execute recognition on [wavPath]. If [todoId] is provided, updates that
  /// todo; otherwise inserts a new recognizing todo and completes it.
  Future<TodoItem?> execute({required String wavPath, String? todoId}) async {
    String activeId = todoId ?? '';

    try {
      final settings = await _settingsRepository.loadSettings();

      // Ensure a recognizing todo exists
      if (activeId.isEmpty) {
        final inserted = await _repository.insertRecognizing(
          audioPath: wavPath,
          text: '',
          priority: settings.defaultTodoPriority,
        );
        activeId = inserted.id;
      } else {
        await _repository.updateToRecognizing(activeId, audioPath: wavPath);
      }

      // Perform recognition
      final resultText = await _recognition.recognize(wavPath) ?? '';
      var normalized = resultText.trim();

      // Optional: remove trailing period if enabled
      if (settings.autoRemoveTrailingPeriod && normalized.isNotEmpty) {
        if (normalized.endsWith('.') || normalized.endsWith('。')) {
          normalized = normalized.substring(0, normalized.length - 1).trim();
        }
      }

      if (normalized.isEmpty) {
        await _repository.markFailed(
            id: activeId, errorMessage: 'Empty transcription');
        return null;
      }

      // Save original ASR output as rawTranscript and normalized text as display text
      await _repository.completeRecognition(
          id: activeId, text: normalized, rawTranscript: resultText);

      foundation.debugPrint('Todo created successfully: $activeId');

      return await _repository.getTodoById(activeId);
    } catch (e) {
      foundation.debugPrint('Error in create todo workflow: $e');
      if (activeId.isNotEmpty) {
        try {
          await _repository.markFailed(
              id: activeId, errorMessage: e.toString());
        } catch (inner) {
          foundation.debugPrint('Also failed to mark todo failed: $inner');
        }
      }
      return null;
    }
  }
}
