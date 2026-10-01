import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/news_item.dart';
import '../services/api_service.dart';
import '../services/voice_service.dart';
import '../widgets/ai_sphere.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({
    super.key,
    required this.api,
    required this.voice,
    required this.onPremiumRequired,
  });

  final ApiService api;
  final VoiceService voice;
  final VoidCallback onPremiumRequired;

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  List<NewsItem> _items = const [];
  bool _loading = true;
  bool _voiceGuidance = false;
  bool _voiceChoiceAsked = false;
  String? _error;
  int? _selectedIndex;

  @override
  void initState() {
    super.initState();
    widget.voice.registerHandler('news', _handleVoiceCommand);
    widget.voice.addListener(_voiceChanged);
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) => _askVoicePreference());
  }

  void _voiceChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.voice.unregisterHandler('news');
    widget.voice.removeListener(_voiceChanged);
    super.dispose();
  }

  Future<void> _askVoicePreference() async {
    if (_voiceChoiceAsked || !mounted) return;
    _voiceChoiceAsked = true;
    final useVoice = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Use voice in News?'),
        content: const Text(
          'You can browse all verified headlines silently, or enable voice guidance. If enabled, Wealth Assistant will read only the story you select and will never move to another story until you ask.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Read silently')),
          FilledButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.volume_up_rounded),
            label: const Text('Enable voice'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => _voiceGuidance = useVoice == true);
    if (_voiceGuidance) {
      await widget.voice.speak('Voice guidance is on. Choose a headline, or say open news followed by a number.');
    }
  }

  Future<void> _load({bool refresh = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await widget.api.topNews(refresh: refresh);
      if (mounted) setState(() => _items = items);
    } on ApiException catch (error) {
      if (error.statusCode == 402) widget.onPremiumRequired();
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _handleVoiceCommand(String command) async {
    final lower = command.toLowerCase().trim();

    if (lower.contains('turn voice off') ||
    lower.contains('silent mode')) {
  await widget.voice.stopSpeaking();

  if (mounted) {
    setState(() => _voiceGuidance = false);
  }

  return true;
}
    if (lower.contains('turn voice on') || lower.contains('voice guidance')) {
      if (mounted) setState(() => _voiceGuidance = true);
      await widget.voice.speak('Voice guidance is on.');
      return true;
    }

    if (_selectedIndex != null) {
      final item = _items[_selectedIndex!];
      if (lower == 'read this' || lower.contains('read this news') || lower.contains('read overview')) {
        await _speakItem(item);
        return true;
      }
      if (lower.contains('open source') || lower.contains('open article') || lower.contains('read original')) {
        await _openSource(item);
        return true;
      }
      if (lower.contains('close news') || lower == 'back') {
  await widget.voice.stopSpeaking();

  if (mounted) {
    setState(() => _selectedIndex = null);
  }

  return true;
}
      if (lower.contains('next news') || lower == 'next') {
        final next = _selectedIndex! + 1;
        if (next < _items.length) await _selectItem(next, speak: _voiceGuidance);
        return true;
      }
      if (lower.contains('previous news') || lower == 'previous') {
        final previous = _selectedIndex! - 1;
        if (previous >= 0) await _selectItem(previous, speak: _voiceGuidance);
        return true;
      }
    }

    final numberMatch = RegExp(r'(?:open|read|show)\s+(?:news\s+)?(\d{1,2})').firstMatch(lower);
    if (numberMatch != null) {
      final number = int.tryParse(numberMatch.group(1) ?? '');
      if (number != null && number >= 1 && number <= _items.length) {
        await _selectItem(number - 1, speak: _voiceGuidance);
        return true;
      }
    }

    for (var i = 0; i < _items.length; i++) {
      final titleWords = _items[i].title.toLowerCase().split(RegExp(r'\s+')).where((word) => word.length >= 5);
      if (titleWords.any(lower.contains) && (lower.contains('open') || lower.contains('read') || lower.contains('show'))) {
        await _selectItem(i, speak: _voiceGuidance);
        return true;
      }
    }
    return false;
  }

  Future<void> _selectItem(
  int index, {
  bool speak = false,
}) async {
  if (index < 0 ||
      index >= _items.length ||
      !mounted) {
    return;
  }

  // Stop any story that may already be speaking.
  await widget.voice.stopSpeaking();

  if (!mounted) return;

  setState(() => _selectedIndex = index);

  if (speak) {
    await _speakItem(_items[index]);
  }
}

  Future<void> _speakItem(NewsItem item) async {
    final signal = item.marketSignal == 'uncertain'
        ? 'The market context is uncertain.'
        : 'The possible sector context is ${item.marketSignal} for ${item.sector}.';
    await widget.voice.speak(
      '${item.title}. ${item.overview}. $signal ${item.rationale}. This is an AI generated overview for informational purposes only and is not an investment recommendation.',
    );
  }

  Future<void> _openSource(NewsItem item) async {
    final uri = Uri.tryParse(item.link);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Color _signalColor(String signal) {
    return switch (signal) {
      'tailwind' => Colors.green,
      'headwind' => Colors.redAccent,
      'mixed' => Colors.orange,
      _ => Theme.of(context).colorScheme.secondary,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedIndex != null && _selectedIndex! < _items.length) {
      return _detail(_items[_selectedIndex!], _selectedIndex!);
    }

    return RefreshIndicator(
      onRefresh: () => _load(refresh: true),
      child: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Industry pulse'),
            actions: [
              IconButton(
  tooltip:
      _voiceGuidance
          ? 'Voice guidance on'
          : 'Voice guidance off',
  onPressed: () async {
    final nextValue = !_voiceGuidance;

    if (!nextValue) {
      await widget.voice.stopSpeaking();
    }

    if (!mounted) return;

    setState(() {
      _voiceGuidance = nextValue;
    });
  },
  icon: Icon(
    _voiceGuidance
        ? Icons.volume_up_rounded
        : Icons.volume_off_rounded,
  ),
),
              IconButton(onPressed: () => _load(refresh: true), icon: const Icon(Icons.refresh_rounded)),
            ],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      SizedBox(width: 92, height: 92, child: AiSphere(state: widget.voice.state)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Verified news only', style: TextStyle(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 4),
                            Text(
                              _voiceGuidance
                                  ? 'Voice is ready. Say “open news 3” or tap any story.'
                                  : 'Browse the top stories. Turn on voice only when you want spoken guidance.',
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            SliverFillRemaining(
              child: Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center))),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 120),
              sliver: SliverList.builder(
                itemCount: _items.length + 1,
                itemBuilder: (context, index) {
                  if (index == _items.length) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'AI-generated news analysis for informational purposes only. It does not guarantee market performance and is not an investment recommendation.',
                        textAlign: TextAlign.center,
                      ),
                    );
                  }
                  final item = _items[index];
                  final signalColor = _signalColor(item.marketSignal);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _selectItem(index, speak: _voiceGuidance),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(radius: 15, child: Text('${index + 1}')),
                                const SizedBox(width: 10),
                                Expanded(child: Text(item.source, style: Theme.of(context).textTheme.labelMedium)),
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  label: Text(item.marketSignal.toUpperCase()),
                                  side: BorderSide(color: signalColor.withValues(alpha: 0.5)),
                                  avatar: CircleAvatar(backgroundColor: signalColor, radius: 5),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(item.title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                            const SizedBox(height: 8),
                            Text(item.overview, maxLines: 3, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                const Icon(Icons.touch_app_rounded, size: 16),
                                const SizedBox(width: 5),
                                const Expanded(child: Text('Tap to open overview')),
                                TextButton.icon(
                                  onPressed: () => _openSource(item),
                                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                                  label: const Text('Source'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _detail(NewsItem item, int index) {
    final signalColor = _signalColor(item.marketSignal);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
  onPressed: () async {
    await widget.voice.stopSpeaking();

    if (!mounted) return;

    setState(() => _selectedIndex = null);
  },
  icon: const Icon(Icons.arrow_back_rounded),
),
        title: Text('News ${index + 1} of ${_items.length}'),
        actions: [
          IconButton(
            tooltip: 'Read overview aloud',
            onPressed: () => _speakItem(item),
            icon: const Icon(Icons.volume_up_rounded),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.source, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Text(item.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            Chip(
              label: Text('${item.marketSignal.toUpperCase()} • ${item.sector}'),
              avatar: CircleAvatar(backgroundColor: signalColor, radius: 5),
            ),
            const SizedBox(height: 16),
            Text('Verified-source overview', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(item.overview),
            const SizedBox(height: 18),
            Text('Possible market context', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(item.rationale),
            const SizedBox(height: 20),
            Text('Exact source link', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            SelectableText(
              item.link,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: () => _openSource(item),
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Open original source'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _speakItem(item),
                  icon: const Icon(Icons.record_voice_over_rounded),
                  label: const Text('Read overview aloud'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'AI-generated overview for informational purposes only. It does not guarantee market performance and is not an investment recommendation.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 12),
            const Text('WealthPilot will stay on this story until you tap another one or explicitly say “next news”.'),
          ],
        ),
      ),
    );
  }
}
