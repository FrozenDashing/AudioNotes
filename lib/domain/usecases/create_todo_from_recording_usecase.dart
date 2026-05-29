import '../../services/recorder_service.dart';
import '../../services/recognition_service.dart';
import '../../data/todo_repository.dart';
import '../../repositories/settings_repository.dart';
import '../../models/todo_priority.dart';

/// Use case for creating a todo from audio recording
/// This is the core workflow: Record → Save WAV → Recognize → Create Todo
class CreateTodoFromRecordingUseCase {
  final RecorderService _recorder;
  final RecognitionService _recognition;
  final TodoRepository _repository;
  final SettingsRepository? _settingsRepository;

  CreateTodoFromRecordingUseCase({
    required RecorderService recorder,
    required RecognitionService recognition,
    required TodoRepository repository,
    SettingsRepository? settingsRepository,
  })  : _recorder = recorder,
        _recognition = recognition,
        _repository = repository,
        _settingsRepository = settingsRepository;

  /// Execute the complete workflow
  Future<void> execute() async {
    String? wavPath;
    String? todoId;
    bool autoRemoveTrailingPeriod = false;

    try {
      // Step 1: Stop recording and get WAV file path
      wavPath = await _recorder.stopRecording();

      if (wavPath == null || wavPath.isEmpty) {
        throw Exception('error.recordingFileGenerationFailed');
      }

      // Step 2: Insert todo in recognizing state
      TodoPriority priority = TodoPriority.normal;
      if (_settingsRepository != null) {
        try {
          final settings = await _settingsRepository!.loadSettings();
          priority = settings.defaultTodoPriority;
          autoRemoveTrailingPeriod = settings.autoRemoveTrailingPeriod;
        } catch (_) {}
      }

      final todo = await _repository.insertRecognizing(
        audioPath: wavPath,
        priority: priority,
      );
      todoId = todo.id;

      // Step 3: Recognize the audio file
      String? text = await _recognition.recognize(wavPath);

      if (text == null || text.isEmpty) {
        throw Exception('error.speechRecognitionFailed');
      }

      // ✅ Clean up extra spaces: replace multiple consecutive spaces with single space and trim
      text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

      if (autoRemoveTrailingPeriod) {
        text = text.replaceFirst(RegExp(r'[。.]$'), '');
      }

      // Step 4: Complete recognition successfully with heuristic confidence
      double computeConfidence(String t) {
        final len = t.length;
        if (len < 4) return 0.3;
        final base = ((len.clamp(4, 200) - 4) / 196).clamp(0.0, 1.0);
        var conf = 0.5 + base * 0.45;
        final cjkCount = RegExp(r'[\u4E00-\u9FFF]').allMatches(t).length;
        if (cjkCount / len > 0.5) conf = (conf + 0.05).clamp(0.0, 1.0);
        return conf;
      }

      final confidence = computeConfidence(text);

      await _repository.completeRecognition(
        id: todoId,
        text: text,
        modelVersion: 'vosk-model-small-cn-0.22',
        confidence: confidence,
      );

      print('Todo created successfully: $todoId');
    } catch (e) {
      print('Error in create todo workflow: $e');

      // Mark as failed if we have a todo ID
      if (todoId != null) {
        await _repository.markFailed(
          id: todoId,
          errorMessage: e.toString(),
        );
      }

      rethrow;
    }
  }
}
