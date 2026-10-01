class ChartPoint {
  const ChartPoint({
    required this.label,
    required this.value,
    this.secondaryValue,
    this.direction,
    this.category,
  });

  final String label;
  final double value;
  final double? secondaryValue;
  final String? direction;
  final String? category;

  factory ChartPoint.fromJson(Map<String, dynamic> json) => ChartPoint(
        label: '${json['label'] ?? ''}',
        value: (json['value'] as num?)?.toDouble() ?? 0,
        secondaryValue: (json['secondaryValue'] as num?)?.toDouble(),
        direction: json['direction']?.toString(),
        category: json['category']?.toString(),
      );
}

class VisualizationSpec {
  const VisualizationSpec({
    required this.type,
    required this.title,
    required this.series,
    required this.highlightSequence,
    this.subtitle,
  });

  final String type;
  final String title;
  final String? subtitle;
  final List<ChartPoint> series;
  final List<String> highlightSequence;

  factory VisualizationSpec.fromJson(Map<String, dynamic> json) => VisualizationSpec(
        type: '${json['type'] ?? 'bar'}',
        title: '${json['title'] ?? 'Financial insight'}',
        subtitle: json['subtitle']?.toString(),
        series: ((json['series'] as List?) ?? const [])
            .whereType<Map>()
            .map((item) => ChartPoint.fromJson(Map<String, dynamic>.from(item)))
            .toList(),
        highlightSequence: ((json['highlightSequence'] as List?) ?? const [])
            .map((item) => item.toString())
            .toList(),
      );
}

class SuggestedAction {
  const SuggestedAction({
    required this.title,
    required this.reason,
    required this.monthlyImpact,
  });

  final String title;
  final String reason;
  final double monthlyImpact;

  factory SuggestedAction.fromJson(Map<String, dynamic> json) => SuggestedAction(
        title: '${json['title'] ?? ''}',
        reason: '${json['reason'] ?? ''}',
        monthlyImpact: (json['monthlyImpact'] as num?)?.toDouble() ?? 0,
      );
}

class GoalProposal {
  const GoalProposal({
    required this.action,
    required this.goalName,
    required this.goalType,
    required this.targetAmount,
    required this.targetDate,
    required this.requiresApproval,
    required this.canApply,
    this.goalId,
  });

  final String action;
  final String? goalId;
  final String goalName;
  final String goalType;
  final double targetAmount;
  final String? targetDate;
  final bool requiresApproval;
  final bool canApply;

  factory GoalProposal.fromJson(Map<String, dynamic> json) => GoalProposal(
        action: '${json['action'] ?? 'create'}',
        goalId: json['goalId']?.toString(),
        goalName: '${json['goalName'] ?? ''}',
        goalType: '${json['goalType'] ?? 'savings'}',
        targetAmount: (json['targetAmount'] as num?)?.toDouble() ?? 0,
        targetDate: json['targetDate']?.toString(),
        requiresApproval: json['requiresApproval'] != false,
        canApply: json['canApply'] != false,
      );

  Map<String, dynamic> approvedPayload() => {
        'approved': true,
        'action': action,
        if (goalId != null) 'goalId': goalId,
        'goalName': goalName,
        'name': goalName,
        'goalType': goalType,
        'targetAmount': targetAmount,
        if (targetDate != null) 'targetDate': targetDate,
      };
}

class AssistantResponse {
  const AssistantResponse({
    required this.answer,
    this.visualization,
    this.actions = const [],
    this.goalProposal,
  });

  final String answer;
  final VisualizationSpec? visualization;
  final List<SuggestedAction> actions;
  final GoalProposal? goalProposal;

  factory AssistantResponse.fromJson(Map<String, dynamic> json) => AssistantResponse(
        answer: '${json['answer'] ?? ''}',
        visualization: json['visualization'] is Map
            ? VisualizationSpec.fromJson(Map<String, dynamic>.from(json['visualization'] as Map))
            : null,
        actions: (((json['suggestedActions'] as Map?)?['actions'] as List?) ?? const [])
            .whereType<Map>()
            .map((item) => SuggestedAction.fromJson(Map<String, dynamic>.from(item)))
            .toList(),
        goalProposal: json['goalProposal'] is Map
            ? GoalProposal.fromJson(Map<String, dynamic>.from(json['goalProposal'] as Map))
            : null,
      );
}
