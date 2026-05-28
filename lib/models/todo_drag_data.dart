class TodoDragData {
  final String todoId;
  final String? sourceCategoryId;
  final String sourceGroupKey;
  final int sourceIndex;

  const TodoDragData({
    required this.todoId,
    required this.sourceCategoryId,
    required this.sourceGroupKey,
    required this.sourceIndex,
  });
}
