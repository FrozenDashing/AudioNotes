import 'todo_sort.dart';

/// Query options for fetching todo items.
class TodoQueryOptions {
  final TodoSortField sortField;
  final SortDirection direction;
  final bool onlyPending;
  final String? categoryId;

  const TodoQueryOptions({
    this.sortField = TodoSortField.manual,
    this.direction = SortDirection.asc,
    this.onlyPending = false,
    this.categoryId,
  });

  TodoQueryOptions copyWith({
    TodoSortField? sortField,
    SortDirection? direction,
    bool? onlyPending,
    String? categoryId,
  }) {
    return TodoQueryOptions(
      sortField: sortField ?? this.sortField,
      direction: direction ?? this.direction,
      onlyPending: onlyPending ?? this.onlyPending,
      categoryId: categoryId ?? this.categoryId,
    );
  }
}
