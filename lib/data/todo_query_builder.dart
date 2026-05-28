import '../models/todo_sort.dart';

/// Builds SQL snippets for todo sorting.
class TodoQueryBuilder {
  static String buildOrderBy(TodoSortField field, SortDirection direction) {
    final dir = direction == SortDirection.asc ? 'ASC' : 'DESC';

    switch (field) {
      case TodoSortField.manual:
        return 'CASE WHEN order_index IS NULL THEN 1 ELSE 0 END, '
            'order_index $dir, created_at DESC';
      case TodoSortField.createdAt:
        return 'created_at $dir';
      case TodoSortField.dueAt:
        return 'CASE WHEN due_at IS NULL THEN 1 ELSE 0 END, due_at $dir';
      case TodoSortField.priority:
        return 'priority $dir, created_at DESC';
    }
  }
}
