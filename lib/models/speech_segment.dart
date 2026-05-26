/// Represents a speech recognition segment from VAD
class SpeechSegment {
  final String segmentId;
  final String text;
  final int startTimestamp;
  final int endTimestamp;
  final String audioPath;
  final double? confidence;
  final bool isFinal;

  const SpeechSegment({
    required this.segmentId,
    required this.text,
    required this.startTimestamp,
    required this.endTimestamp,
    required this.audioPath,
    this.confidence,
    this.isFinal = true,
  });

  factory SpeechSegment.fromMap(Map<String, dynamic> map) {
    return SpeechSegment(
      segmentId: map['segment_id'] as String? ?? '',
      text: map['text'] as String? ?? '',
      startTimestamp: map['start_ts'] as int? ?? 0,
      endTimestamp: map['end_ts'] as int? ?? 0,
      audioPath: map['audio_path'] as String? ?? '',
      confidence: map['confidence'] as double?,
      isFinal: map['is_final'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'segment_id': segmentId,
      'text': text,
      'start_ts': startTimestamp,
      'end_ts': endTimestamp,
      'audio_path': audioPath,
      'confidence': confidence,
      'is_final': isFinal,
    };
  }
}

/// Represents partial transcription result during streaming
class PartialTranscript {
  final String text;
  final int timestamp;
  final bool isFinal;

  const PartialTranscript({
    required this.text,
    required this.timestamp,
    this.isFinal = false,
  });

  factory PartialTranscript.fromMap(Map<String, dynamic> map) {
    return PartialTranscript(
      text: map['text'] as String? ?? '',
      timestamp: map['timestamp'] as int? ?? 0,
      isFinal: map['is_final'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'timestamp': timestamp,
      'is_final': isFinal,
    };
  }
}
