class FinancialGoal {
  const FinancialGoal({
    required this.id,
    required this.name,
    required this.goalType,
    required this.targetAmount,
    required this.targetDate,
    required this.isActive,
  });

  final String id;
  final String name;
  final String goalType;
  final double targetAmount;
  final String? targetDate;
  final bool isActive;

  factory FinancialGoal.fromJson(Map<String, dynamic> json) => FinancialGoal(
        id: '${json['id'] ?? ''}',
        name: '${json['name'] ?? ''}',
        goalType: '${json['goalType'] ?? 'savings'}',
        targetAmount: (json['targetAmount'] as num?)?.toDouble() ?? 0,
        targetDate: json['targetDate']?.toString(),
        isActive: json['isActive'] != false,
      );
}
