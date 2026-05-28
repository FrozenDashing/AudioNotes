/// Priority for todo items.
enum TodoPriority {
  low(0),
  normal(1),
  high(2),
  urgent(3);

  final int value;
  const TodoPriority(this.value);

  static TodoPriority fromValue(int? value) {
    switch (value) {
      case 0:
        return TodoPriority.low;
      case 2:
        return TodoPriority.high;
      case 3:
        return TodoPriority.urgent;
      case 1:
      default:
        return TodoPriority.normal;
    }
  }
}
