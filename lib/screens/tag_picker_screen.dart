import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/tag.dart';
import '../providers/app_providers.dart';
import 'tag_create_screen.dart';

class TagPickerScreen extends ConsumerStatefulWidget {
  final List<String> initialSelected;

  const TagPickerScreen({super.key, this.initialSelected = const []});

  @override
  ConsumerState<TagPickerScreen> createState() => _TagPickerScreenState();
}

class _TagPickerScreenState extends ConsumerState<TagPickerScreen> {
  late Set<String> _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialSelected.toSet();
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(tagListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Tags'),
      ),
      body: tagsAsync.when(
        data: (tags) {
          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: tags.length + 1,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    if (index == tags.length) {
                      return ListTile(
                        leading: const Icon(Icons.add),
                        title: const Text('Create new tag'),
                        onTap: () async {
                          final created = await Navigator.push<Tag?>(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TagCreateScreen(),
                            ),
                          );
                          if (created != null && context.mounted) {
                            ref.invalidate(tagListProvider);
                            ref.invalidate(tagsForTodoProvider);
                          }
                        },
                      );
                    }

                    final tag = tags[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            tag.color != null ? Color(tag.color!) : null,
                        child: const Icon(Icons.label, color: Colors.white),
                      ),
                      title: Text(tag.name),
                      subtitle: const Text('长按编辑/删除'),
                      onLongPress: () => _showTagActions(context, tag),
                      trailing: Checkbox(
                        value: _selected.contains(tag.id),
                        onChanged: (v) {
                          setState(() {
                            if (v == true) {
                              _selected.add(tag.id);
                            } else {
                              _selected.remove(tag.id);
                            }
                          });
                        },
                      ),
                      onTap: () {
                        setState(() {
                          if (_selected.contains(tag.id)) {
                            _selected.remove(tag.id);
                          } else {
                            _selected.add(tag.id);
                          }
                        });
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () =>
                            Navigator.pop(context, _selected.toList()),
                        child: const Text('Apply'),
                      ),
                    ),
                  ],
                ),
              )
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
      ),
    );
  }

  Future<void> _showTagActions(BuildContext context, Tag tag) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('编辑标签'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _editTag(context, tag);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('删除标签', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _deleteTag(context, tag);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editTag(BuildContext context, Tag tag) async {
    final controller = TextEditingController(text: tag.name);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('编辑标签'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              labelText: '标签名称',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('保存'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    final name = controller.text.trim();
    if (name.isEmpty) {
      return;
    }

    await ref.read(tagRepositoryProvider).updateTag(tag.copyWith(name: name));
    ref.invalidate(tagListProvider);
    ref.invalidate(tagsForTodoProvider);
  }

  Future<void> _deleteTag(BuildContext context, Tag tag) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('删除标签'),
          content: Text('确定删除“${tag.name}”？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await ref.read(tagRepositoryProvider).deleteTag(tag.id);
    setState(() {
      _selected.remove(tag.id);
    });
    ref.invalidate(tagListProvider);
    ref.invalidate(tagsForTodoProvider);
  }
}
