class DashboardCategory {
  const DashboardCategory({required this.category, required this.amount});
  final String category;
  final double amount;

  factory DashboardCategory.fromJson(Map<String, dynamic> json) => DashboardCategory(
        category: '${json['category'] ?? 'Other'}',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
      );
}

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.moneyIn,
    required this.moneyOut,
    required this.activityFound,
    required this.largestCategory,
  });

  final double moneyIn;
  final double moneyOut;
  final int activityFound;
  final String largestCategory;

  factory DashboardSnapshot.fromJson(Map<String, dynamic> json) => DashboardSnapshot(
        moneyIn: (json['moneyIn'] as num?)?.toDouble() ?? 0,
        moneyOut: (json['moneyOut'] as num?)?.toDouble() ?? 0,
        activityFound: (json['activityFound'] as num?)?.toInt() ?? 0,
        largestCategory: '${json['largestCategory'] ?? '—'}',
      );
}

class DashboardData {
  const DashboardData({
    required this.snapshot,
    required this.categories,
    required this.periodLabel,
  });

  final DashboardSnapshot snapshot;
  final List<DashboardCategory> categories;
  final String periodLabel;

  factory DashboardData.fromJson(Map<String, dynamic> json) {
    final period = json['period'] is Map ? Map<String, dynamic>.from(json['period'] as Map) : <String, dynamic>{};
    final start = '${period['startDate'] ?? ''}';
    final end = '${period['endDate'] ?? ''}';
    return DashboardData(
      snapshot: DashboardSnapshot.fromJson(
        json['snapshot'] is Map ? Map<String, dynamic>.from(json['snapshot'] as Map) : <String, dynamic>{},
      ),
      categories: ((json['categories'] as List?) ?? const [])
          .whereType<Map>()
          .map((item) => DashboardCategory.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      periodLabel: start.isNotEmpty && end.isNotEmpty ? '$start → $end' : 'Latest statement period',
    );
  }
}
