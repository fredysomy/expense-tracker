class Account {
  final String id;
  final String name;
  final String type; // 'regular' | 'credit'
  final String currency;
  final double balance;
  final DateTime createdAt;

  Account({
    required this.id,
    required this.name,
    required this.type,
    required this.currency,
    required this.balance,
    required this.createdAt,
  });

  bool get isCredit => type == 'credit';

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'type': type,
        'currency': currency,
        'balance': balance,
        'created_at': createdAt.toIso8601String(),
      };

  factory Account.fromMap(Map<String, dynamic> map) => Account(
        id: map['id'] as String,
        name: map['name'] as String,
        type: map['type'] as String,
        currency: map['currency'] as String,
        balance: (map['balance'] as num).toDouble(),
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Account copyWith({
    String? id,
    String? name,
    String? type,
    String? currency,
    double? balance,
    DateTime? createdAt,
  }) =>
      Account(
        id: id ?? this.id,
        name: name ?? this.name,
        type: type ?? this.type,
        currency: currency ?? this.currency,
        balance: balance ?? this.balance,
        createdAt: createdAt ?? this.createdAt,
      );
}
