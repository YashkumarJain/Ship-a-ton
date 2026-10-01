import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/assistant_response.dart';
import '../services/api_service.dart';
import '../services/voice_service.dart';
import '../widgets/ai_sphere.dart';
import '../widgets/dynamic_financial_chart.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({
    super.key,
    required this.api,
    required this.voice,
    required this.commandBus,
    required this.goalsReload,
    required this.onPremiumRequired,
  });

  final ApiService api;
  final VoiceService voice;
  final ValueNotifier<String?> commandBus;
  final ValueNotifier<int> goalsReload;
  final VoidCallback onPremiumRequired;

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _controller = TextEditingController();
  AssistantResponse? _response;
  bool _busy = false;
  bool _applyingGoal = false;
  String? _error;
  int _requestId = 0;
  String? _spokenCategory;


  @override
  void initState() {
    super.initState();
    widget.voice.registerHandler('assistant', _voiceCommand);
    widget.voice.addListener(_voiceChanged);
    widget.commandBus.addListener(_commandBusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _commandBusChanged());
  }

  Future<bool> _voiceCommand(String command) async {
    await _submitMessage(command);
    return true;
  }

  void _commandBusChanged() {
    final command = widget.commandBus.value;
    if (command == null || command.trim().isEmpty) return;
    widget.commandBus.value = null;
    _submitMessage(command);
  }

  void _voiceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _submitMessage(String text) async {
  final message = text.trim();
  if (message.isEmpty) return;

  final requestId = ++_requestId;

  _controller.clear();

  // Stop the previous spoken answer immediately.
  await widget.voice.stopSpeaking();

  if (!mounted || requestId != _requestId) return;

  setState(() {
    _busy = true;
    _error = null;
    _response = null;
    _spokenCategory = null;
  });

  try {
    final response = await widget.api.chat(message);

    // Ignore an old API response if a newer question was submitted.
    if (!mounted || requestId != _requestId) return;

    setState(() {
      _response = response;
    });

    HapticFeedback.mediumImpact();

    await _speakWithChartSync(
  response.answer,
  requestId,
);

  } on ApiException catch (error) {
    if (!mounted || requestId != _requestId) return;

    if (error.statusCode == 402) {
      widget.onPremiumRequired();
    } else {
      setState(() => _error = error.message);
    }
  } catch (error) {
    if (!mounted || requestId != _requestId) return;

    setState(() => _error = '$error');
  } finally {
    if (mounted && requestId == _requestId) {
      setState(() => _busy = false);
    }
  }
}

Future<void> _speakWithChartSync(
  String answer,
  int requestId,
) async {
  final parts = answer
      .split(RegExp(r'\n+'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();

  for (final part in parts) {
    if (!mounted || requestId != _requestId) return;

    final lower = part.toLowerCase();
    String? category;

    if (lower.contains('rent')) {
      category = 'Rent';
    } else if (lower.contains('travel')) {
      category = 'Travel';
    } else if (lower.contains('shopping') ||
        lower.contains('amazon') ||
        lower.contains('target')) {
      category = 'Shopping';
    } else if (lower.contains('dining') ||
        lower.contains('restaurant') ||
        lower.contains('starbucks')) {
      category = 'Dining';
    } else if (lower.contains('grocer') ||
        lower.contains('whole foods')) {
      category = 'Groceries';
    } else if (lower.contains('transport') ||
        lower.contains('uber') ||
        lower.contains('gas')) {
      category = 'Transport';
    } else if (lower.contains('subscription') ||
        lower.contains('netflix') ||
        lower.contains('spotify')) {
      category = 'Subscriptions';
    } else if (lower.contains('utilities') ||
        lower.contains('electric') ||
        lower.contains('internet')) {
      category = 'Utilities';
    }

    if (category != null) {
      setState(() {
        _spokenCategory = category;
      });

      await Future.delayed(
        const Duration(milliseconds: 250),
      );
    }

    await widget.voice.speak(part);
  }
}

  Future<void> _approveGoal(GoalProposal proposal) async {
    final verb = switch (proposal.action) {
      'update' => 'change',
      'delete' => 'delete',
      _ => 'create',
    };
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Approve goal ${proposal.action}?'),
        content: Text(
          proposal.action == 'delete'
              ? 'Wealth Assistant proposes deleting “${proposal.goalName}”. No change will happen unless you approve.'
              : 'Wealth Assistant proposes to $verb “${proposal.goalName}” with a target of \$${proposal.targetAmount.toStringAsFixed(0)}${proposal.targetDate != null ? ' by ${proposal.targetDate}' : ''}. No change will happen unless you approve.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Do not change anything')),
          FilledButton(onPressed: proposal.canApply ? () => Navigator.pop(context, true) : null, child: const Text('Approve')),
        ],
      ),
    );
    if (approved != true) return;

    setState(() => _applyingGoal = true);
    try {
      await widget.api.applyGoalProposal(proposal);
      widget.goalsReload.value += 1;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Goal ${proposal.action} approved and saved.')),
        );
        setState(() {
          if (_response != null) {
            _response = AssistantResponse(
              answer: _response!.answer,
              visualization: _response!.visualization,
              actions: _response!.actions,
            );
          }
        });
      }
    } on ApiException catch (error) {
      if (error.statusCode == 402) widget.onPremiumRequired();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _applyingGoal = false);
    }
  }

  @override
  void dispose() {
    widget.voice.unregisterHandler('assistant');
    widget.voice.removeListener(_voiceChanged);
    widget.commandBus.removeListener(_commandBusChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 720;
          final spherePanel = _spherePanel(context);
          final insightPanel = _insightPanel(context);
          return Column(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                  child: wide
                      ? Row(
                          children: [
                            Flexible(flex: 2, child: spherePanel),
                            const SizedBox(width: 12),
                            Flexible(flex: 8, child: insightPanel),
                          ],
                        )
                      : Column(
                          children: [
                            Flexible(flex: 2, child: spherePanel),
                            const SizedBox(height: 10),
                            Flexible(flex: 8, child: insightPanel),
                          ],
                        ),
                ),
              ),
              _composer(context),
            ],
          );
        },
      ),
    );
  }

  Widget _spherePanel(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 150),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AiSphere(state: _busy ? 'thinking' : widget.voice.state),
              const SizedBox(height: 8),
              Text(
                _busy
                    ? 'Thinking across your finances…'
                    : widget.voice.state == 'speaking'
                        ? 'Explaining your insight'
                        : widget.voice.partial.isNotEmpty
                            ? widget.voice.partial
                            : 'Say “Hey Wealth Assistant”',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              IconButton(
                tooltip: widget.voice.enabled ? 'Disable wake phrase' : 'Enable wake phrase',
                onPressed: () => widget.voice.setEnabled(!widget.voice.enabled),
                icon: Icon(widget.voice.enabled ? Icons.mic_rounded : Icons.mic_off_rounded),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _insightPanel(BuildContext context) {
    return Column(
      children: [
        Expanded(
          flex: 6,
          child: DynamicFinancialChart(
  key: ValueKey(_spokenCategory),
  spec: _response?.visualization,
  animateHighlight: _spokenCategory != null,
  highlightLabel: _spokenCategory,
),
        ),
        const SizedBox(height: 10),
        Expanded(
          flex: 4,
          child: Card(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Wealth Assistant', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  if (_error != null)
                    Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))
                  else if (_response == null)
                    const Text('Ask why your spending changed, whether you can reach a savings goal, how much is safe to spend, or what to change next month.')
                  else ...[
                    Text(_response!.answer),
                    if (_response!.goalProposal != null) ...[
                      const SizedBox(height: 14),
                      _goalProposalCard(context, _response!.goalProposal!),
                    ],
                    if (_response!.actions.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text('Action ideas', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      for (final action in _response!.actions)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Icon(Icons.auto_awesome_rounded, size: 16),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  action.monthlyImpact > 0
                                      ? '${action.title} — about \$${action.monthlyImpact.toStringAsFixed(0)}/mo scenario. ${action.reason}'
                                      : '${action.title}. ${action.reason}',
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _goalProposalCard(BuildContext context, GoalProposal proposal) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.35),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.approval_outlined, size: 19),
              SizedBox(width: 8),
              Expanded(child: Text('Approval required', style: TextStyle(fontWeight: FontWeight.w900))),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${proposal.action.toUpperCase()}: ${proposal.goalName}'
            '${proposal.action != 'delete' ? ' • \$${proposal.targetAmount.toStringAsFixed(0)}${proposal.targetDate != null ? ' • ${proposal.targetDate}' : ''}' : ''}',
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: _applyingGoal || !proposal.canApply ? null : () => _approveGoal(proposal),
            icon: _applyingGoal
                ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_circle_outline_rounded),
            label: Text(proposal.canApply ? 'Review & approve' : 'Matching goal not found'),
          ),
        ],
      ),
    );
  }

  Widget _composer(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 4,
        bottom: MediaQuery.paddingOf(context).bottom + 10,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.send,
              onSubmitted: _submitMessage,
              decoration: const InputDecoration(
                hintText: 'Ask about your money…',
                prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _busy ? null : () => _submitMessage(_controller.text),
            icon: _busy
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.arrow_upward_rounded),
          ),
        ],
      ),
    );
  }
}
