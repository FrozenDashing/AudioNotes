import 'package:flutter/material.dart';
import '../models/settings_state.dart';

/// Widget for selecting theme color with preset options and custom color picker
class ThemeColorPicker extends StatefulWidget {
  final ThemeModeOption currentThemeMode;
  final Color? currentCustomColor;
  final Function(ThemeModeOption) onThemeModeChanged;
  final Function(Color) onCustomColorChanged;

  const ThemeColorPicker({
    super.key,
    required this.currentThemeMode,
    this.currentCustomColor,
    required this.onThemeModeChanged,
    required this.onCustomColorChanged,
  });

  @override
  State<ThemeColorPicker> createState() => _ThemeColorPickerState();
}

class _ThemeColorPickerState extends State<ThemeColorPicker> {
  late Color _selectedCustomColor;

  @override
  void initState() {
    super.initState();
    _selectedCustomColor = widget.currentCustomColor ?? Colors.blue;
  }

  @override
  void didUpdateWidget(covariant ThemeColorPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentCustomColor != oldWidget.currentCustomColor &&
        widget.currentCustomColor != null) {
      _selectedCustomColor = widget.currentCustomColor!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Preset theme colors
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildThemeOption(
              '默认',
              Theme.of(context).colorScheme.primary,
              ThemeModeOption.light,
            ),
            _buildThemeOption(
              '蓝色',
              Colors.blue,
              ThemeModeOption.custom,
              customColor: Colors.blue,
            ),
            _buildThemeOption(
              '暖橙',
              Colors.orange,
              ThemeModeOption.custom,
              customColor: Colors.orange,
            ),
            _buildThemeOption(
              '深绿',
              Colors.green,
              ThemeModeOption.custom,
              customColor: Colors.green,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Follow system option
        Row(
          children: [
            const Text('跟随系统'),
            const Spacer(),
            Switch(
              value: widget.currentThemeMode == ThemeModeOption.system,
              onChanged: (value) {
                widget.onThemeModeChanged(
                  value
                      ? ThemeModeOption.system
                      : (widget.currentCustomColor != null
                          ? ThemeModeOption.custom
                          : ThemeModeOption.light),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Custom color picker
        Row(
          children: [
            const Text('自定义颜色'),
            const Spacer(),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: _selectedCustomColor,
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _showColorPickerDialog,
            ),
          ],
        ),

        // Theme preview
        const SizedBox(height: 16),
        const Text('预览:', style: TextStyle(fontSize: 14)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _getCurrentThemeColor().withValues(alpha: 0.1),
            border: Border.all(color: _getCurrentThemeColor()),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Container(
                height: 40,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _getCurrentThemeColor(),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Center(
                  child: Text(
                    '主题色预览',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Checkbox(
                    value: false,
                    onChanged: (_) {},
                    activeColor: _getCurrentThemeColor(),
                  ),
                  const Text('待办项示例'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThemeOption(
    String label,
    Color color,
    ThemeModeOption mode, {
    Color? customColor,
  }) {
    final isSelected = widget.currentThemeMode == mode &&
        (mode != ThemeModeOption.custom ||
            widget.currentCustomColor == customColor);

    return GestureDetector(
      onTap: () {
        if (mode == ThemeModeOption.custom && customColor != null) {
          setState(() {
            _selectedCustomColor = customColor;
          });
          widget.onCustomColorChanged(customColor);
        }
        widget.onThemeModeChanged(mode);
      },
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCurrentThemeColor() {
    if (widget.currentThemeMode == ThemeModeOption.system) {
      return Theme.of(context).colorScheme.primary;
    } else if (widget.currentThemeMode == ThemeModeOption.custom &&
        widget.currentCustomColor != null) {
      return widget.currentCustomColor!;
    } else {
      return Theme.of(context).colorScheme.primary;
    }
  }

  void _showColorPickerDialog() async {
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('选择主题色'),
              content: SingleChildScrollView(
                child: ColorPickerGrid(
                  selectedColor: _selectedCustomColor,
                  onColorChanged: (color) {
                    setState(() {
                      _selectedCustomColor = color;
                    });
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () {
                    widget.onCustomColorChanged(_selectedCustomColor);
                    widget.onThemeModeChanged(ThemeModeOption.custom);
                    Navigator.pop(context);
                  },
                  child: const Text('确定'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Grid of colors for selection
class ColorPickerGrid extends StatelessWidget {
  final Color selectedColor;
  final Function(Color) onColorChanged;

  const ColorPickerGrid({
    super.key,
    required this.selectedColor,
    required this.onColorChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = [
      Colors.red,
      Colors.pink,
      Colors.purple,
      Colors.deepPurple,
      Colors.indigo,
      Colors.blue,
      Colors.lightBlue,
      Colors.cyan,
      Colors.teal,
      Colors.green,
      Colors.lightGreen,
      Colors.lime,
      Colors.yellow,
      Colors.amber,
      Colors.orange,
      Colors.deepOrange,
      Colors.brown,
      Colors.grey,
      Colors.blueGrey,
    ];

    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: colors.map((color) {
        return GestureDetector(
          onTap: () => onColorChanged(color),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color:
                    selectedColor == color ? Colors.black : Colors.transparent,
                width: 2,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
