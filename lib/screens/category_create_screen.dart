import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_i18n.dart';
import '../providers/app_providers.dart';

class CategoryCreateScreen extends ConsumerStatefulWidget {
  const CategoryCreateScreen({super.key});

  @override
  ConsumerState<CategoryCreateScreen> createState() =>
      _CategoryCreateScreenState();
}

class _CategoryCreateScreenState extends ConsumerState<CategoryCreateScreen> {
  final TextEditingController _nameController = TextEditingController();
  int _selectedColorIndex = 0;

  static const List<Color> _colors = [
    Color(0xFFE57373),
    Color(0xFFF06292),
    Color(0xFFBA68C8),
    Color(0xFF9575CD),
    Color(0xFF7986CB),
    Color(0xFF64B5F6),
    Color(0xFF4FC3F7),
    Color(0xFF4DD0E1),
    Color(0xFF4DB6AC),
    Color(0xFF81C784),
    Color(0xFFFFB74D),
    Color(0xFFA1887F),
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('category.createTitle')),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('category.nameLabel'),
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: context.tr('category.nameHint'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.tr('category.colorLabel'),
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_colors.length, (index) {
                  final color = _colors[index];
                  final selected = _selectedColorIndex == index;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColorIndex = index),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(color: Colors.white, width: 2)
                            : null,
                      ),
                      child: selected
                          ? const Icon(Icons.check,
                              size: 16, color: Colors.white)
                          : null,
                    ),
                  );
                }),
              ),
              const Spacer(),
              Row(
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(context.tr('common.cancel')),
                  ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () async {
                      final name = _nameController.text.trim();
                      if (name.isEmpty) return;
                      final color = _colors[_selectedColorIndex].toARGB32();
                      final navigator = Navigator.of(context);
                      final category = await ref
                          .read(categoryRepositoryProvider)
                          .createCategory(name: name, color: color);
                      if (!mounted) return;
                      navigator.pop(category);
                    },
                    child: Text(context.tr('category.createAction')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
