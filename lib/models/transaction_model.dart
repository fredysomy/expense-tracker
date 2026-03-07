class TransactionModel {
  final String id;
  final double amount;
  final String accountId;
  final String categoryId;
  final DateTime date;
  final String? note;
  final List<String> tags;
  final DateTime createdAt;

  const TransactionModel({
    required this.id,
    required this.amount,
    required this.accountId,
    required this.categoryId,
    required this.date,
    this.note,
    this.tags = const [],
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'amount': amount,
        'account_id': accountId,
        'category_id': categoryId,
        'date': date.toIso8601String(),
        'note': note,
        'tags': tags.join(','),
        'created_at': createdAt.toIso8601String(),
      };

  factory TransactionModel.fromMap(Map<String, dynamic> map) =>
      TransactionModel(
        id: map['id'] as String,
        amount: (map['amount'] as num).toDouble(),
        accountId: map['account_id'] as String,
        categoryId: map['category_id'] as String,
        date: DateTime.parse(map['date'] as String),
        note: map['note'] as String?,
        tags: map['tags'] != null && (map['tags'] as String).isNotEmpty
            ? (map['tags'] as String).split(',')
            : [],
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  TransactionModel copyWith({
    String? id,
    double? amount,
    String? accountId,
    String? categoryId,
    DateTime? date,
    String? note,
    List<String>? tags,
    DateTime? createdAt,
  }) =>
      TransactionModel(
        id: id ?? this.id,
        amount: amount ?? this.amount,
        accountId: accountId ?? this.accountId,
        categoryId: categoryId ?? this.categoryId,
        date: date ?? this.date,
        note: note ?? this.note,
        tags: tags ?? this.tags,
        createdAt: createdAt ?? this.createdAt,
      );
}
