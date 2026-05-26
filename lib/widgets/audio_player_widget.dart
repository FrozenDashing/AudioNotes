import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import '../providers/app_providers.dart';

/// Widget for playing back audio recordings
class AudioPlayerWidget extends ConsumerStatefulWidget {
  final String audioPath;

  const AudioPlayerWidget({
    super.key,
    required this.audioPath,
  });

  @override
  ConsumerState<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends ConsumerState<AudioPlayerWidget> {
  bool isPlaying = false;
  Duration position = Duration.zero;
  Duration duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  void _setupListeners() {
    final playbackService = ref.read(audioPlaybackServiceProvider);
    // Update only when the global player is playing this widget's audioPath
    playbackService.currentAudioPathStream.listen((currentPath) {
      if (mounted) {
        setState(() {
          isPlaying = currentPath == widget.audioPath &&
              playbackService.getCurrentState() == PlayerState.playing;
        });
      }
    });

    playbackService.positionStream.listen((pos) {
      if (mounted) {
        if (playbackService.currentAudioPath == widget.audioPath) {
          setState(() {
            position = pos;
          });
        }
      }
    });

    playbackService.durationStream.listen((dur) {
      if (mounted) {
        if (playbackService.currentAudioPath == widget.audioPath) {
          setState(() {
            duration = dur;
          });
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: Icon(isPlaying ? Icons.stop : Icons.play_arrow),
          onPressed: () async {
            final playbackService = ref.read(audioPlaybackServiceProvider);

            if (isPlaying) {
              await playbackService.stop();
            } else {
              await playbackService.play(widget.audioPath);
            }
          },
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 1.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 6,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: duration.inMilliseconds > 0
                          ? position.inMilliseconds / duration.inMilliseconds
                          : 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    // Stop playback when widget is disposed
    ref.read(audioPlaybackServiceProvider).stop();
    super.dispose();
  }
}
