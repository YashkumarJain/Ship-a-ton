import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  final _scrollController = ScrollController();
  final List<_ChatEntry> _messages = [];

  AssistantResponse? _response;
  bool _busy = false;
  bool _applyingGoal = false;
  bool _loadingHistory = true;
  String? _error;
  int _requestId = 0;
  String? _spokenCategory;

  String get _historyKey => 'assistant_chat_v2_${widget.api.localUserKey}';

  @override
  void initState() {
    super.initState();
    widget.voice.registerHandler('assistant', _voiceCommand);
    widget.voice.addListener(_voiceChanged);
    widget.commandBus.addListener(_commandBusChanged);
    _loadHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) => _commandBusChanged());
  }

  Future<void> _loadHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_historyKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final restored = decoded
              .whereType<Map>()
              .map((item) => _ChatEntry.fromJson(Map<String, dynamic>.from(item)))
              .where((item) => item.text.trim().isNotEmpty)
              .toList();
          if (mounted) {
            setState(() {
              _messages
                ..clear()
                ..addAll(restored.takeLast(60));
              _response = _latestResponse();
            });
          }
        }
      }
    } catch (_) {
      // Corrupt local chat history should never block the assistant.
    } finally {
      if (mounted) setState(() => _loadingHistory = false);
      _scrollToBottom();
    }
  }

  AssistantResponse? _latestResponse() {
    for (final entry in _messages.reversed) {
      if (entry.response != null) return entry.response;
    }
    return null;
  }

  Future<void> _saveHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = _messages.length > 60
        ? _messages.sublist(_messages.length - 60)
        : List<_ChatEntry>.from(_messages);
    await prefs.setString(
      _historyKey,
      jsonEncode(trimmed.map((item) => item.toJson()).toList()),
    );
  }

  Future<void> _clearHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear assistant chat?'),
        content: const Text('This removes the saved chat history on this device.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.voice.stopSpeaking();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyKey);
    if (!mounted) return;
    setState(() {
      _messages.clear();
      _response = null;
      _spokenCategory = null;
      _error = null;
    });
  }

  List<Map<String, String>> _conversationContext() {
    final recent = _messages.length > 10
        ? _messages.sublist(_messages.length - 10)
        : _messages;
    return recent
        .map((item) => {
              'role': item.role,
              'content': item.text.length > 1800
                  ? item.text.substring(0, 1800)
                  : item.text,
            })
        .toList();
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
    if (message.isEmpty || _busy) return;

    final requestId = ++_requestId;
    final contextHistory = _conversationContext();
    _controller.clear();
    await widget.voice.stopSpeaking();
    if (!mounted || requestId != _requestId) return;

    setState(() {
      _busy = true;
      _error = null;
      _response = null;
      _spokenCategory = null;
      _messages.add(_ChatEntry(role: 'user', text: message));
    });
    await _saveHistory();
    _scrollToBottom();

    try {
      final response = await widget.api.chat(
        message,
        history: contextHistory,
      );
      if (!mounted || requestId != _requestId) return;

      setState(() {
        _response = response;
        _busy = false;
        _messages.add(
          _ChatEntry(
            role: 'assistant',
            text: response.answer,
            response: response,
          ),
        );
      });
      await _saveHistory();
      _scrollToBottom();
      HapticFeedback.mediumImpact();

      if (widget.voice.speakerEnabled) {
        await _speakWithChartSync(response.answer, requestId);
      }
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
      if (mounted && requestId == _requestId && _busy) {
        setState(() => _busy = false);
      }
    }
  }

  String? _highlightForPart(String part) {
    final spec = _response?.visualization;
    if (spec == null) return null;
    final lower = part.toLowerCase();
    for (final point in spec.series) {
      final candidates = [point.label, if (point.category != null) point.category!];
      for (final candidate in candidates) {
        final value = candidate.trim().toLowerCase();
        if (value.isNotEmpty && lower.contains(value)) return point.label;
      }
    }
    return null;
  }

 Future<void> _speakWithChartSync(
  String answer,
  int requestId,
) async {
  if (!mounted ||
      requestId != _requestId ||
      !widget.voice.speakerEnabled) {
    return;
  }

  String? lastHighlight;

  if (_spokenCategory != null) {
    setState(() => _spokenCategory = null);
  }

  await widget.voice.speak(
    answer,
    onProgress: (
      String spokenText,
      int start,
      int end,
      String word,
    ) {
      if (!mounted || requestId != _requestId) {
        return;
      }

      final spec = _response?.visualization;
      if (spec == null || spec.series.isEmpty) {
        return;
      }

      final currentWord = word
          .toLowerCase()
          .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
          .trim();

      if (currentWord.isEmpty) {
        return;
      }

      String? nextHighlight;

      for (final point in spec.series) {
        final candidates = <String>[
          point.label,
          if (point.category != null) point.category!,
        ];

        for (final candidate in candidates) {
          final normalized = candidate
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
              .trim();

          if (normalized == currentWord ||
              normalized.split(' ').contains(currentWord)) {
            nextHighlight = point.label;
            break;
          }
        }

        if (nextHighlight != null) {
          break;
        }
      }

      if (nextHighlight != null &&
          nextHighlight != lastHighlight) {
        lastHighlight = nextHighlight;

        setState(() {
          _spokenCategory = nextHighlight;
        });
      }
    },
  );

  if (!mounted || requestId != _requestId) {
    return;
  }

  await Future<void>.delayed(
    const Duration(milliseconds: 350),
  );

  if (mounted) {
    setState(() {
      _spokenCategory = null;
    });
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
              ? 'Delete “${proposal.goalName}”? No change happens until you approve.'
              : '$verb “${proposal.goalName}” with a target of \$${proposal.targetAmount.toStringAsFixed(0)}${proposal.targetDate != null ? ' by ${proposal.targetDate}' : ''}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: proposal.canApply ? () => Navigator.pop(context, true) : null,
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (approved != true) return;

    setState(() => _applyingGoal = true);
    try {
      await widget.api.applyGoalProposal(proposal);
      widget.goalsReload.value += 1;
      if (!mounted) return;
      final current = _response;
      if (current != null) {
        final updated = AssistantResponse(
          answer: current.answer,
          visualization: current.visualization,
          actions: current.actions,
        );
        setState(() {
          _response = updated;
          for (var i = _messages.length - 1; i >= 0; i--) {
            if (_messages[i].response != null) {
              _messages[i] = _ChatEntry(
                role: _messages[i].role,
                text: _messages[i].text,
                response: updated,
              );
              break;
            }
          }
        });
        await _saveHistory();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Goal ${proposal.action} saved.')),
        );
      }
    } on ApiException catch (error) {
      if (error.statusCode == 402) widget.onPremiumRequired();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _applyingGoal = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  void dispose() {
    widget.voice.unregisterHandler('assistant');
    widget.voice.removeListener(_voiceChanged);
    widget.commandBus.removeListener(_commandBusChanged);
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 860;
          return Column(
            children: [
              _assistantHeader(context),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                  child: wide
                      ? Row(
                          children: [
                            Expanded(flex: 6, child: _chatPanel(context)),
                            if (_response?.visualization != null) ...[
                              const SizedBox(width: 12),
                              Expanded(flex: 4, child: _chartPanel()),
                            ],
                          ],
                        )
                      : Column(
                          children: [
                            if (_response?.visualization != null) ...[
                              SizedBox(height: 220, child: _chartPanel()),
                              const SizedBox(height: 8),
                            ],
                            Expanded(child: _chatPanel(context)),
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

  Widget _assistantHeader(BuildContext context) {
    final voiceStatus = widget.voice.lastError != null
        ? widget.voice.lastError!
        : _busy
            ? 'Thinking…'
            : widget.voice.state == 'speaking'
                ? 'Speaking answer'
                : widget.voice.state == 'listening'
                    ? widget.voice.partial
                    : widget.voice.enabled
                        ? 'Wake phrase on'
                        : 'Wake phrase off • tap mic to talk';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: AiSphere(state: _busy ? 'thinking' : widget.voice.state),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Wealth Assistant',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  voiceStatus,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: widget.voice.speakerEnabled ? 'Turn speaker off' : 'Turn speaker on',
            onPressed: () => widget.voice.setSpeakerEnabled(!widget.voice.speakerEnabled),
            icon: Icon(
              widget.voice.speakerEnabled
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
            ),
          ),
          IconButton(
            tooltip: widget.voice.enabled ? 'Turn wake phrase off' : 'Turn wake phrase on',
            onPressed: () => widget.voice.setEnabled(!widget.voice.enabled),
            icon: Icon(
              widget.voice.enabled ? Icons.hearing_rounded : Icons.hearing_disabled_rounded,
            ),
          ),
          IconButton(
            tooltip: 'Clear chat',
            onPressed: _messages.isEmpty ? null : _clearHistory,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
    );
  }

Widget _chartPanel() {
  final spec = _response?.visualization;

  final fingerprint = spec?.series
          .map(
            (point) =>
                '${point.label}:${point.value}:${point.secondaryValue ?? ''}',
          )
          .join('|') ??
      'no-chart';

  return DynamicFinancialChart(
    key: ValueKey(
      '${spec?.type}|${spec?.title}|$fingerprint',
    ),
    spec: spec,
    animateHighlight: _spokenCategory != null,
    highlightLabel: _spokenCategory,
  );
}

  Widget _chatPanel(BuildContext context) {
    if (_loadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          if (_error != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(_error!),
            ),
          Expanded(
            child: _messages.isEmpty
                ? _emptyChat(context)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 18),
                    itemCount: _messages.length + (_busy ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (_busy && index == _messages.length) {
                        return _thinkingBubble(context);
                      }
                      final item = _messages[index];
                      final isLatestAssistant = item.role == 'assistant' &&
                          index == _messages.lastIndexWhere((entry) => entry.role == 'assistant');
                      return _messageBubble(context, item, isLatestAssistant);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _emptyChat(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 38,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Ask a money question',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try “Why did my spending increase?” or “Can I reach my vacation goal?”',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thinkingBubble(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const SizedBox(
          width: 56,
          child: LinearProgressIndicator(minHeight: 3),
        ),
      ),
    );
  }

  Widget _messageBubble(
    BuildContext context,
    _ChatEntry item,
    bool isLatestAssistant,
  ) {
    final user = item.role == 'user';
    final response = item.response;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 720),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
        decoration: BoxDecoration(
          color: user
              ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.72)
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.text),
            if (!user && isLatestAssistant && response?.goalProposal != null) ...[
              const SizedBox(height: 12),
              _goalProposalCard(context, response!.goalProposal!),
            ],
            if (!user && isLatestAssistant && response != null && response.actions.isNotEmpty) ...[
              const SizedBox(height: 10),
              for (final action in response.actions.take(3))
                Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.arrow_right_rounded, size: 18),
                      const SizedBox(width: 4),
                      Expanded(child: Text(action.title)),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _goalProposalCard(BuildContext context, GoalProposal proposal) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.28),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${proposal.action.toUpperCase()}: ${proposal.goalName}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          if (proposal.action != 'delete') ...[
            const SizedBox(height: 4),
            Text(
              '\$${proposal.targetAmount.toStringAsFixed(0)}${proposal.targetDate != null ? ' • ${proposal.targetDate}' : ''}',
            ),
          ],
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: _applyingGoal || !proposal.canApply
                ? null
                : () => _approveGoal(proposal),
            icon: _applyingGoal
                ? const SizedBox.square(
                    dimension: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_outline_rounded),
            label: Text(proposal.canApply ? 'Review & approve' : 'Goal not found'),
          ),
        ],
      ),
    );
  }

  Widget _composer(BuildContext context) {
    final listening = widget.voice.state == 'listening';
    return Padding(
      padding: EdgeInsets.fromLTRB(
        12,
        5,
        12,
        MediaQuery.paddingOf(context).bottom + 10,
      ),
      child: Row(
        children: [
          IconButton.filledTonal(
            tooltip: listening ? 'Listening…' : 'Talk to Wealth Assistant',
            onPressed: _busy ? null : () => widget.voice.listenForCommand(),
            icon: Icon(listening ? Icons.mic_rounded : Icons.mic_none_rounded),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: !_busy,
              textInputAction: TextInputAction.send,
              onSubmitted: _submitMessage,
              decoration: const InputDecoration(
                hintText: 'Ask about your money…',
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: 'Send',
            onPressed: _busy ? null : () => _submitMessage(_controller.text),
            icon: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_upward_rounded),
          ),
        ],
      ),
    );
  }
}

class _ChatEntry {
  const _ChatEntry({
    required this.role,
    required this.text,
    this.response,
  });

  final String role;
  final String text;
  final AssistantResponse? response;

  factory _ChatEntry.fromJson(Map<String, dynamic> json) => _ChatEntry(
        role: json['role'] == 'assistant' ? 'assistant' : 'user',
        text: '${json['text'] ?? ''}',
        response: json['response'] is Map
            ? AssistantResponse.fromJson(
                Map<String, dynamic>.from(json['response'] as Map),
              )
            : null,
      );

  Map<String, dynamic> toJson() => {
        'role': role,
        'text': text,
        if (response != null) 'response': response!.toJson(),
      };
}

extension _TakeLast<T> on List<T> {
  Iterable<T> takeLast(int count) {
    if (length <= count) return this;
    return sublist(length - count);
  }
}
