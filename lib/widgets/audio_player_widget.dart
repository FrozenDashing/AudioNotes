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
    
    playbackService.stateStream.listen((state) {
      if (mounted) {
        setState(() {
          isPlaying = state == PlayerState.playing;
        });
      }
    });
    
    playbackService.positionStream.listen((pos) {
      if (mounted) {
        setState(() {
          position = pos;
        });
      }
    });
    
    playbackService.durationStream.listen((dur) {
      if (mounted) {
        setState(() {
          duration = dur;
        });
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
            padding: const EdgeInsets.only(top: 8.0), // ✅ Move progress bar up to align with play button triangle
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_formatDuration(position)} / ${_formatDuration(duration)}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                LinearProgressIndicator(
                  value: duration.inMilliseconds > 0 
                      ? position.inMilliseconds / duration.inMilliseconds 
                      : 0,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    // Stop playback when widget is disposed
    ref.read(audioPlaybackServiceProvider).stop();
    super.dispose();
  }
}
