import 'package:flutter/material.dart';
import '../l10n/app_i18n.dart';

/// Overlay widget shown during recording
class RecordingOverlay extends StatefulWidget {
  final bool isProcessing;
  final String partialText;

  const RecordingOverlay({
    super.key,
    required this.isProcessing,
    required this.partialText,
  });

  @override
  State<RecordingOverlay> createState() => _RecordingOverlayState();
}

class _RecordingOverlayState extends State<RecordingOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _rippleController;
  final List<_Ripple> _ripples = [];
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    // Ripple controller drives continuously; each cycle spawns a new ring
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _ripples.add(_Ripple(startAt: _rippleController.value));
          _rippleController.forward(from: 0.0);
        }
      });

    // Pulse controller for the inner mic circle gentle breathing
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    // Kick off the first ripple immediately
    _ripples.add(_Ripple(startAt: 0.0));
    _rippleController.forward();
  }

  @override
  void dispose() {
    _rippleController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Recording indicator
                if (widget.isProcessing)
                  const CircularProgressIndicator()
                else
                  _buildRecordingIndicator(isDark),

                const SizedBox(height: 16),

                Text(
                  widget.isProcessing
                      ? context.tr('todo.overlay.processing')
                      : context.tr('todo.overlay.recording'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 16),

                // Partial transcript display
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(
                    minHeight: 60,
                    maxHeight: 200,
                  ),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      widget.partialText.isEmpty
                          ? context.tr('todo.overlay.listening')
                          : widget.partialText,
                      style: TextStyle(
                        fontSize: 16,
                        color: widget.partialText.isEmpty
                            ? Colors.grey[600]
                            : Colors.black,
                      ),
                    ),
                  ),
                ),

                if (!widget.isProcessing) ...[
                  const SizedBox(height: 16),
                  Text(
                    context.tr('todo.overlay.hint'),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecordingIndicator(bool isDark) {
    const micSize = 60.0;
    const ringMaxSize = 140.0;

    return SizedBox(
      width: ringMaxSize,
      height: ringMaxSize,
      child: AnimatedBuilder(
        animation: Listenable.merge([_rippleController, _pulseController]),
        builder: (context, _) {
          // Remove ripples that have fully faded out
          _ripples.removeWhere((r) => r.progress(_rippleController) >= 1.0);

          return Stack(
            alignment: Alignment.center,
            children: [
              // Outgoing ripple rings
              ..._ripples.map((ripple) {
                final t = ripple.progress(_rippleController);
                final scale = 1.0 + t * ((ringMaxSize / micSize) - 1.0);
                final opacity = (1.0 - t).clamp(0.0, 1.0) * 0.5;

                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: micSize,
                    height: micSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.red.withValues(alpha: opacity),
                        width: 2.0 + (1.0 - t) * 2.0,
                      ),
                    ),
                  ),
                );
              }),

              // Outer background circle with pulse
              Transform.scale(
                scale: 1.0 + _pulseController.value * 0.08,
                child: Container(
                  width: micSize + 16,
                  height: micSize + 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withValues(alpha: 0.15),
                  ),
                ),
              ),

              // Inner solid circle
              Container(
                width: micSize,
                height: micSize,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red,
                ),
              ),

              // Microphone icon
              const Icon(
                Icons.mic,
                color: Colors.white,
                size: 30,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Model for a single expanding ripple ring.
class _Ripple {
  final double startAt;
  _Ripple({required this.startAt});

  /// Returns 0..1 progress within the ripple cycle.
  double progress(AnimationController controller) {
    if (controller.value < startAt) return 0.0;
    return ((controller.value - startAt) / (1.0 - startAt)).clamp(0.0, 1.0);
  }
}
