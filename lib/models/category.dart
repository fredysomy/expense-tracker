class Category {
  final String id;
  final String name;
  final String type; // 'income' | 'expense'
  final String icon;
  final String? parentId; // null = top-level category

  Category({
    required this.id,
    required this.name,
    required this.type,
    required this.icon,
    this.parentId,
  });

  bool get isExpense => type == 'expense';
  bool get isIncome => type == 'income';
  bool get isSubcategory => parentId != null;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type,
        'icon': icon,
        'parent_id': parentId,
      };

  factory Category.fromMap(Map<String, dynamic> map) => Category(
        id: map['id'] as String,
        name: map['name'] as String,
        type: map['type'] as String,
        icon: map['icon'] as String,
        parentId: map['parent_id'] as String?,
      );

  Category copyWith({
    String? id,
    String? name,
    String? type,
    String? icon,
    String? parentId,
  }) =>
      Category(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        icon: icon ?? this.icon,
        parentId: parentId ?? this.parentId,
      );
}
