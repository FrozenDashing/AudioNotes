import 'package:uuid/uuid.dart';
import '../models/tag.dart';
import 'database_helper.dart';

class TagRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final Uuid _uuid = const Uuid();

  Future<List<Tag>> getTags() async {
    return _dbHelper.getTags();
  }

  Future<Tag> createTag({
    required String name,
    int? color,
  }) async {
    final tag = Tag(
      id: _uuid.v4(),
      name: name,
      color: color,
    );
    await _dbHelper.insertTag(tag);
    return tag;
  }

  Future<void> updateTag(Tag tag) async {
    await _dbHelper.updateTagData(tag);
  }

  Future<void> deleteTag(String id) async {
    await _dbHelper.deleteTag(id);
  }

  Future<List<Tag>> getTagsForTodo(String todoId) async {
    return _dbHelper.getTagsForTodo(todoId);
  }

  Future<void> setTagsForTodo(String todoId, List<String> tagIds) async {
    await _dbHelper.setTagsForTodo(todoId, tagIds);
  }
}
