class Budget {
  final String id;
  final String name;
  final double limitAmount;
  final String period; // 'daily' | 'weekly' | 'monthly'
  final DateTime startDate;
  final DateTime createdAt;
  final List<String> categoryIds;
  final List<String> accountIds;

  const Budget({
    required this.id,
    required this.name,
    required this.limitAmount,
    required this.period,
    required this.startDate,
    required this.createdAt,
    this.categoryIds = const [],
    this.accountIds = const [],
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'limit_amount': limitAmount,
        'period': period,
        'start_date': startDate.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };

  factory Budget.fromMap(Map<String, dynamic> map) => Budget(
        id: map['id'] as String,
        name: map['name'] as String,
        limitAmount: (map['limit_amount'] as num).toDouble(),
        period: map['period'] as String,
        startDate: DateTime.parse(map['start_date'] as String),
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  Budget copyWith({
    String? id,
    String? name,
    double? limitAmount,
    String? period,
    DateTime? startDate,
    DateTime? createdAt,
    List<String>? categoryIds,
    List<String>? accountIds,
  }) =>
      Budget(
        id: id ?? this.id,
        name: name ?? this.name,
        limitAmount: limitAmount ?? this.limitAmount,
        period: period ?? this.period,
        startDate: startDate ?? this.startDate,
        createdAt: createdAt ?? this.createdAt,
        categoryIds: categoryIds ?? this.categoryIds,
        accountIds: accountIds ?? this.accountIds,
      );

  (DateTime, DateTime) get currentPeriodRange {
    final now = DateTime.now();
    switch (period) {
      case 'daily':
        final start = DateTime(now.year, now.month, now.day);
        return (start, start.add(const Duration(days: 1)));
      case 'weekly':
        final weekday = now.weekday;
        final start = DateTime(now.year, now.month, now.day - (weekday - 1));
        return (start, start.add(const Duration(days: 7)));
      case 'monthly':
      default:
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 1);
        return (start, end);
    }
  }

  int get daysInPeriod {
    final (start, end) = currentPeriodRange;
    return end.difference(start).inDays;
  }

  int get daysElapsed {
    final (start, _) = currentPeriodRange;
    final now = DateTime.now();
    return now.difference(start).inDays + 1;
  }
}
