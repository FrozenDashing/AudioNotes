import 'dart:async';
import 'package:audioplayers/audioplayers.dart';

/// Service for playing back recorded audio files
class AudioPlaybackService {
  final AudioPlayer _player = AudioPlayer();

  Stream<PlayerState> get stateStream => _player.onPlayerStateChanged;
  Stream<Duration> get positionStream => _player.onPositionChanged;
  Stream<Duration> get durationStream => _player.onDurationChanged;

  String? _currentAudioPath;
  final _currentPathController = StreamController<String?>.broadcast();

  Stream<String?> get currentAudioPathStream => _currentPathController.stream;
  String? get currentAudioPath => _currentAudioPath;

  /// Play an audio file
  Future<void> play(String audioPath) async {
    try {
      await _player.stop();
      _currentAudioPath = audioPath;
      _currentPathController.add(_currentAudioPath);
      await _player.setSource(DeviceFileSource(audioPath));
      await _player.resume();
    } catch (e) {
      print('Error playing audio: $e');
      rethrow;
    }
  }

  /// Pause playback
  Future<void> pause() async {
    await _player.pause();
  }

  /// Resume playback
  Future<void> resume() async {
    await _player.resume();
  }

  /// Stop playback
  Future<void> stop() async {
    await _player.stop();
    _currentAudioPath = null;
    _currentPathController.add(null);
  }

  /// Seek to position
  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  /// Get current player state
  PlayerState? getCurrentState() {
    return _player.state;
  }

  /// Dispose resources
  void dispose() {
    _player.dispose();
    _currentPathController.close();
  }
}
