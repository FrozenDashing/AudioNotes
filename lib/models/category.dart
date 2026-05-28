class Category {
  final String id;
  final String name;
  final int? color;
  final int sortOrder;
  final bool isHidden;

  const Category({
    required this.id,
    required this.name,
    this.color,
    this.sortOrder = 0,
    this.isHidden = false,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      color: json['color'] as int?,
      sortOrder: json['sort_order'] as int? ?? 0,
      isHidden: (json['is_hidden'] as int? ?? 0) == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'sort_order': sortOrder,
      'is_hidden': isHidden ? 1 : 0,
    };
  }

  Category copyWith({
    String? id,
    String? name,
    int? color,
    int? sortOrder,
    bool? isHidden,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      sortOrder: sortOrder ?? this.sortOrder,
      isHidden: isHidden ?? this.isHidden,
    );
  }
}
