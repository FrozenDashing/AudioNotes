import 'package:uuid/uuid.dart';
import '../models/category.dart';
import 'database_helper.dart';

class CategoryRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final Uuid _uuid = const Uuid();

  Future<List<Category>> getCategories({bool includeHidden = false}) async {
    return _dbHelper.getCategories(includeHidden: includeHidden);
  }

  Future<Category> createCategory({
    required String name,
    int? color,
    int sortOrder = 0,
    bool isHidden = false,
  }) async {
    final category = Category(
      id: _uuid.v4(),
      name: name,
      color: color,
      sortOrder: sortOrder,
      isHidden: isHidden,
    );
    await _dbHelper.insertCategory(category);
    return category;
  }

  Future<void> updateCategory(Category category) async {
    await _dbHelper.updateCategoryData(category);
  }

  Future<void> deleteCategory(String id) async {
    await _dbHelper.deleteCategory(id);
  }
}
