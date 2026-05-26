import 'package:flutter/material.dart';

/// A helper widget that draws a continuous strikethrough across the full width
/// of the text to avoid gaps where spaces would break a normal `TextDecoration`.
class CompletedText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const CompletedText({required this.text, required this.style, super.key});

  @override
  Widget build(BuildContext context) {
    // Calculate an approximate line offset based on font size.
    final fontSize = style.fontSize ?? 16.0;
    final lineOffset = fontSize * 0.55;

    return LayoutBuilder(builder: (context, constraints) {
      return Stack(
        alignment: Alignment.centerLeft,
        children: [
          Text(
            text,
            style: style,
          ),
          Positioned(
            left: 0,
            right: 0,
            top: lineOffset,
            child: Container(
              height: (fontSize * 0.06).clamp(1.0, 3.0),
              color: style.color != null
                  ? style.color!.withAlpha((0.9 * 255).round())
                  : Colors.black.withAlpha((0.6 * 255).round()),
            ),
          ),
        ],
      );
    });
  }
}
