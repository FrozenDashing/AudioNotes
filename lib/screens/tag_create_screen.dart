import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';

class TagCreateScreen extends ConsumerStatefulWidget {
  const TagCreateScreen({super.key});

  @override
  ConsumerState<TagCreateScreen> createState() => _TagCreateScreenState();
}

class _TagCreateScreenState extends ConsumerState<TagCreateScreen> {
  final TextEditingController _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Tag')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Tag name',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final name = _nameController.text.trim();
                      if (name.isEmpty) return;
                      final navigator = Navigator.of(context);
                      final tag = await ref
                          .read(tagRepositoryProvider)
                          .createTag(name: name);
                      if (!mounted) return;
                      navigator.pop(tag);
                    },
                    child: const Text('Create'),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
