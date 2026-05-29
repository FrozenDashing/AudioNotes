import 'package:flutter/material.dart';
import '../l10n/app_i18n.dart';
import '../models/settings_state.dart';

/// Widget for selecting font size with preset options and custom slider
class FontSizeSlider extends StatefulWidget {
  final FontSizeOption currentFontSizeOption;
  final double currentCustomScale;
  final bool followSystemFontSize;
  final Function(FontSizeOption) onFontSizeOptionChanged;
  final Function(double) onCustomScaleChanged;
  final ValueChanged<bool> onFollowSystemFontSizeChanged;

  const FontSizeSlider({
    super.key,
    required this.currentFontSizeOption,
    required this.currentCustomScale,
    required this.followSystemFontSize,
    required this.onFontSizeOptionChanged,
    required this.onCustomScaleChanged,
    required this.onFollowSystemFontSizeChanged,
  });

  @override
  State<FontSizeSlider> createState() => _FontSizeSliderState();
}

class _FontSizeSliderState extends State<FontSizeSlider> {
  late double _customScale;

  @override
  void initState() {
    super.initState();
    _customScale = widget.currentCustomScale;
  }

  @override
  void didUpdateWidget(covariant FontSizeSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentCustomScale != oldWidget.currentCustomScale) {
      _customScale = widget.currentCustomScale;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Preset font size options
        Row(
          children: [
            _buildFontSizeOption(
              context.tr('fontSizePicker.small'),
              FontSizeOption.small,
            ),
            const Spacer(),
            _buildFontSizeOption(
              context.tr('fontSizePicker.medium'),
              FontSizeOption.medium,
            ),
            const Spacer(),
            _buildFontSizeOption(
              context.tr('fontSizePicker.large'),
              FontSizeOption.large,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Custom font size slider
        Row(
          children: [
            Text(context.tr('fontSizePicker.custom')),
            const Spacer(),
            Text('${(_customScale * 100).round()}%'),
          ],
        ),
        Slider(
          value: _customScale,
          min: 0.8,
          max: 1.4,
          divisions: 12, // 80%, 90%, 100%, 110%, 120%, 130%, 140%
          label: '${(_customScale * 100).round()}%',
          onChanged: (value) {
            setState(() {
              _customScale = value;
            });
            widget.onCustomScaleChanged(value);
            widget.onFontSizeOptionChanged(FontSizeOption.custom);
          },
        ),
        const SizedBox(height: 8),

        // Follow system font size option
        Row(
          children: [
            Text(context.tr('fontSizePicker.followSystem')),
            const Spacer(),
            Switch(
              value: widget.followSystemFontSize,
              onChanged: (value) {
                widget.onFollowSystemFontSizeChanged(value);
              },
            ),
          ],
        ),

        // Font size preview
        const SizedBox(height: 16),
        Text(context.tr('fontSizePicker.preview'),
            style: const TextStyle(fontSize: 14)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('fontSizePicker.titlePreview'),
                style: TextStyle(
                  fontSize: 16 * _customScale,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('fontSizePicker.todoPreview'),
                style: TextStyle(
                  fontSize: 14 * _customScale,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.tr('fontSizePicker.completedPreview'),
                style: TextStyle(
                  fontSize: 14 * _customScale,
                  decoration: TextDecoration.lineThrough,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFontSizeOption(String label, FontSizeOption option) {
    final isSelected = widget.currentFontSizeOption == option;

    return GestureDetector(
      onTap: () {
        widget.onFontSizeOptionChanged(option);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Theme.of(context).colorScheme.onPrimary
                : Colors.grey,
          ),
        ),
      ),
    );
  }
}
