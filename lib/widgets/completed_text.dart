import 'package:flutter/material.dart';

/// A helper widget for rendering completed todo text with the configured style.
class CompletedText extends StatelessWidget {
  final String text;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow overflow;

  const CompletedText({
    required this.text,
    required this.style,
    this.maxLines,
    this.overflow = TextOverflow.clip,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: style,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
