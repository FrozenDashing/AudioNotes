import '../../services/recorder_service.dart';
import '../../services/recognition_service.dart';
import '../../data/todo_repository.dart';

/// Use case for creating a todo from audio recording
/// This is the core workflow: Record → Save WAV → Recognize → Create Todo
class CreateTodoFromRecordingUseCase {
  final RecorderService _recorder;
  final RecognitionService _recognition;
  final TodoRepository _repository;

  CreateTodoFromRecordingUseCase({
    required RecorderService recorder,
    required RecognitionService recognition,
    required TodoRepository repository,
  })  : _recorder = recorder,
        _recognition = recognition,
        _repository = repository;

  /// Execute the complete workflow
  Future<void> execute() async {
    String? wavPath;
    String? todoId;

    try {
      // Step 1: Stop recording and get WAV file path
      wavPath = await _recorder.stopRecording();

      if (wavPath == null || wavPath.isEmpty) {
        throw Exception('录音文件生成失败');
      }

      // Step 2: Insert todo in recognizing state
      final todo = await _repository.insertRecognizing(audioPath: wavPath);
      todoId = todo.id;

      // Step 3: Recognize the audio file
      String? text = await _recognition.recognize(wavPath);

      if (text == null || text.isEmpty) {
        throw Exception('未能识别语音内容');
      }

      // ✅ Clean up extra spaces: replace multiple consecutive spaces with single space and trim
      text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

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
