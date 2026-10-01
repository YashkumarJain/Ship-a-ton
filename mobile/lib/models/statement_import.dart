class StatementTransaction {
  StatementTransaction({
    required this.date,
    required this.merchant,
    required this.category,
    required this.amount,
    required this.type,
    required this.confidence,
    required this.fingerprint,
    this.sourceBalance,
    this.sourceOccurrence = 1,
  });

  String date;
  String merchant;
  String category;
  double amount;
  String type;
  double confidence;
  String fingerprint;
  double? sourceBalance;
  int sourceOccurrence;

  factory StatementTransaction.fromJson(Map<String, dynamic> json) => StatementTransaction(
        date: '${json['date'] ?? ''}',
        merchant: '${json['merchant'] ?? ''}',
        category: '${json['category'] ?? 'Other'}',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        type: '${json['type'] ?? 'expense'}',
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
        fingerprint: '${json['fingerprint'] ?? ''}',
        sourceBalance: (json['sourceBalance'] as num?)?.toDouble(),
        sourceOccurrence: (json['sourceOccurrence'] as num?)?.toInt() ?? 1,
      );

  Map<String, dynamic> toJson() => {
        'date': date,
        'merchant': merchant,
        'category': category,
        'amount': amount,
        'type': type,
        'confidence': confidence,
        'fingerprint': fingerprint,
        if (sourceBalance != null) 'sourceBalance': sourceBalance,
        'sourceOccurrence': sourceOccurrence,
      };
}

class StatementImportResult {
  const StatementImportResult({
    required this.transactions,
    required this.warnings,
    required this.extractionMethod,
    required this.privacy,
    required this.newCount,
    required this.overlapCount,
  });

  final List<StatementTransaction> transactions;
  final List<String> warnings;
  final String extractionMethod;
  final String privacy;
  final int newCount;
  final int overlapCount;

  factory StatementImportResult.fromJson(Map<String, dynamic> json) {
    final transactions = ((json['transactions'] as List?) ?? const [])
            .whereType<Map>()
            .map((item) => StatementTransaction.fromJson(Map<String, dynamic>.from(item)))
            .toList();
    final preview = json['importPreview'] is Map
        ? Map<String, dynamic>.from(json['importPreview'] as Map)
        : const <String, dynamic>{};
    return StatementImportResult(
        transactions: transactions,
        warnings: ((json['warnings'] as List?) ?? const []).map((e) => '$e').toList(),
        extractionMethod: '${json['extractionMethod'] ?? 'text'}',
        privacy: '${json['privacy'] ?? ''}',
        newCount: (preview['saved'] as num?)?.toInt() ?? transactions.length,
        overlapCount: (preview['duplicatesSkipped'] as num?)?.toInt() ?? 0,
      );
  }
}
