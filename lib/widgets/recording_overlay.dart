import 'package:flutter/material.dart';

/// Overlay widget shown during recording
class RecordingOverlay extends StatelessWidget {
  final bool isProcessing;
  final String partialText;

  const RecordingOverlay({
    super.key,
    required this.isProcessing,
    required this.partialText,
  });

  @override
  Widget build(BuildContext context) {
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
                if (isProcessing)
                  const CircularProgressIndicator()
                else
                  _buildRecordingIndicator(),
                
                const SizedBox(height: 16),
                
                Text(
                  isProcessing ? 'Processing...' : 'Recording...',
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
                      partialText.isEmpty
                          ? 'Listening...'
                          : partialText,
                      style: TextStyle(
                        fontSize: 16,
                        color: partialText.isEmpty
                            ? Colors.grey[600]
                            : Colors.black,
                      ),
                    ),
                  ),
                ),
                
                if (!isProcessing) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Speak clearly into the microphone',
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

  Widget _buildRecordingIndicator() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red.withValues(alpha: 0.2),
          ),
        ),
        Container(
          width: 60,
          height: 60,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.red,
          ),
        ),
        const Icon(
          Icons.mic,
          color: Colors.white,
          size: 30,
        ),
      ],
    );
  }
}
