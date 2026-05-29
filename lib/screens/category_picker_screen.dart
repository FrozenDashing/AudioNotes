import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../l10n/app_i18n.dart';
import '../models/category.dart';
import '../providers/app_providers.dart';
import 'category_create_screen.dart';

class CategoryPickerScreen extends ConsumerWidget {
  final String? selectedCategoryId;

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

  const CategoryPickerScreen({
    super.key,
    this.selectedCategoryId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoryListProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('category.chooseTitle')),
      ),
      body: SafeArea(
        child: categoriesAsync.when(
          data: (categories) {
            return Column(
              children: [
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 1.05,
                    ),
                    itemCount: categories.length + 1,
                    itemBuilder: (context, index) {
                      if (index == categories.length) {
                        return _CreateCategoryTile(
                          onTap: () async {
                            final created = await Navigator.push<Category>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const CategoryCreateScreen(),
                              ),
                            );
                            if (created != null && context.mounted) {
                              ref.invalidate(categoryListProvider);
                            }
                          },
                        );
                      }

                      final category = categories[index];
                      final isSelected = category.id == selectedCategoryId;
                      return _CategoryTile(
                        category: category,
                        isSelected: isSelected,
                        onTap: () => Navigator.pop(context, category.id),
                        onLongPress: () => _showCategoryActions(
                          context,
                          ref,
                          category,
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final created = await Navigator.push<Category>(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CategoryCreateScreen(),
                          ),
                        );
                        if (created != null && context.mounted) {
                          ref.invalidate(categoryListProvider);
                        }
                      },
                      child: Text(context.tr('category.addAction')),
                    ),
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Text(
              error.toString(),
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showCategoryActions(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(context.tr('category.editTitle')),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _editCategory(context, ref, category);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: Text(context.tr('category.deleteTitle'),
                    style: const TextStyle(color: Colors.red)),
                subtitle: Text(context.tr('category.deleteSubtitle')),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _deleteCategory(context, ref, category);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editCategory(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) async {
    final nameController = TextEditingController(text: category.name);
    var selectedColor = category.color ?? _colors.first.toARGB32();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(context.tr('category.editTitle')),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: context.tr('category.nameLabel'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _colors.map((color) {
                        final isSelected = selectedColor == color.toARGB32();
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              selectedColor = color.toARGB32();
                            });
                          },
                          child: Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: Colors.white, width: 2)
                                  : null,
                            ),
                          ),
                        );
                      }).toList(growable: false),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(context.tr('common.cancel')),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: Text(context.tr('common.save')),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final newName = nameController.text.trim();
    if (newName.isEmpty) {
      return;
    }

    await ref.read(categoryRepositoryProvider).updateCategory(
          category.copyWith(name: newName, color: selectedColor),
        );
    ref.invalidate(categoryListProvider);
    ref.invalidate(todoListProvider);
  }

  Future<void> _deleteCategory(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.tr('category.deleteTitle')),
          content: Text(context.tr('category.deleteConfirmWithName',
              params: {'name': category.name})),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(context.tr('common.cancel')),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(context.tr('common.delete')),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await ref.read(categoryRepositoryProvider).deleteCategory(category.id);
    ref.invalidate(categoryListProvider);
    ref.invalidate(todoListProvider);
    if (selectedCategoryId == category.id && context.mounted) {
      Navigator.pop(context, null);
    }
  }
}

class _CategoryTile extends StatelessWidget {
  final Category category;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _CategoryTile({
    required this.category,
    required this.isSelected,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        Color(category.color ?? Theme.of(context).primaryColor.toARGB32());
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: color,
              child: const Icon(Icons.category, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              category.name,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateCategoryTile extends StatelessWidget {
  final VoidCallback onTap;

  const _CreateCategoryTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Ink(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add_circle_outline, size: 24),
            const SizedBox(height: 8),
            Text(context.tr('category.createNew')),
          ],
        ),
      ),
    );
  }
}
