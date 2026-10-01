class UserProfile {
  const UserProfile({
    required this.displayName,
    required this.age,
    required this.monthlyBudget,
    required this.savingsBalance,
    required this.onboardingComplete,
  });

  final String displayName;
  final int? age;
  final double monthlyBudget;
  final double savingsBalance;
  final bool onboardingComplete;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        displayName: '${json['displayName'] ?? ''}',
        age: (json['age'] as num?)?.toInt(),
        monthlyBudget: (json['monthlyBudget'] as num?)?.toDouble() ?? 0,
        savingsBalance: (json['savingsBalance'] as num?)?.toDouble() ?? 0,
        onboardingComplete: json['onboardingComplete'] == true,
      );
}
