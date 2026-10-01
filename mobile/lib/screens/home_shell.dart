import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/revenuecat_service.dart';
import '../services/theme_service.dart';
import '../services/voice_service.dart';
import 'assistant_screen.dart';
import 'dashboard_screen.dart';
import 'goals_screen.dart';
import 'news_screen.dart';
import 'paywall_screen.dart';
import 'settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.api,
    required this.revenueCat,
    required this.themeService,
    required this.onSignedOut,
  });

  final ApiService api;
  final RevenueCatService revenueCat;
  final ThemeService themeService;
  final VoidCallback onSignedOut;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;
  bool? _premiumAccess;
  bool _checkingAccess = false;
  int? _pendingPremiumIndex;
  late final VoiceService _voice;
  final ValueNotifier<String?> _assistantCommandBus = ValueNotifier(null);
  final ValueNotifier<int> _goalsReload = ValueNotifier(0);
  final List<Widget?> _pageCache = List<Widget?>.filled(5, null);

  static const _scopes = ['home', 'assistant', 'news', 'goals', 'settings'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _voice = VoiceService()
  ..onGlobalCommand = _handleGlobalVoiceCommand
  ..onUnhandledCommand = _routeUnhandledVoiceToAssistant
  ..onWakeDetected = _handleWakeDetected;
    _voice.initialize();
    _refreshAccess();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached ||
        state == AppLifecycleState.inactive) {
      _voice.stopForBackground();
    } else if (state == AppLifecycleState.resumed && _voice.enabled) {
      _refreshAccess();
      _voice.startWakeListening();
    }
  }

  Future<void> _refreshAccess() async {
    if (_checkingAccess) return;
    _checkingAccess = true;
    try {
      final status = await widget.api.subscriptionStatus();
      if (mounted) setState(() => _premiumAccess = status['access'] == true);
    } catch (_) {
      // Keep free features usable if the subscription endpoint is temporarily unavailable.
    } finally {
      _checkingAccess = false;
    }
  }

  bool _isPremiumTab(int index) => index == 1 || index == 2 || index == 3;

  Future<bool> _selectIndex(int index) async {
    if (_isPremiumTab(index)) {
      if (_premiumAccess == null) await _refreshAccess();
      if (_premiumAccess != true) {
        _pendingPremiumIndex = index;
        _openPaywall();
        return false;
      }
    }
    if (!mounted) return false;
    setState(() => _index = index);
    _voice.setActiveScope(_scopes[index]);
    return true;
  }

  void _openPaywall() {
  Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => PaywallScreen(
        revenueCat: widget.revenueCat,
        api: widget.api,
        onUnlocked: () async {
          // Refresh the access value used for premium gating.
          await _refreshAccess();

          if (!mounted) return;

          // SettingsScreen is cached in _pageCache.
          // Remove the old cached instance so it reloads
          // subscriptionStatus() and displays "premium".
          setState(() {
            _pageCache[4] = null;
          });

          // Close the paywall.
          Navigator.of(context).maybePop();

          final target = _pendingPremiumIndex;
          _pendingPremiumIndex = null;

          // If the paywall was opened because the user selected
          // Assistant / News / Goals, continue to that screen.
          if (target != null) {
            await _selectIndex(target);
          }
        },
      ),
    ),
  );
}

  Future<void> _handleWakeDetected() async {
  debugPrint('WAKE CALLBACK RECEIVED');
  if (!mounted) return;

  // "Hey Assistant" should open the Assistant
  // from Home, News, Goals, or Settings.
  if (_index != 1) {
    setState(() {
      _index = 1;
    });
  }

  _voice.setActiveScope('assistant');
}

  Future<bool> _handleGlobalVoiceCommand(String command) async {
    final lower = command.toLowerCase().trim();
    final nav = lower.startsWith('open ') ||
        lower.startsWith('go to ') ||
        lower.startsWith('show ') ||
        lower.startsWith('take me to ');

    if (lower == 'stop' || lower.contains('stop talking') || lower.contains('stop speaking')) {
      await _voice.stopSpeaking();
      return true;
    }
    if (nav && (lower.contains('home') || lower.contains('dashboard') || lower.contains('snapshot'))) {
      await _selectIndex(0);
      return true;
    }
    if (nav && lower.contains('assistant')) {
      await _selectIndex(1);
      return true;
    }
    if (nav && lower.contains('news')) {
  // If we are already on the News screen and the user says
  // "open news 4", "show news 2", etc., let NewsScreen handle it.
  final numberedNewsCommand = RegExp(
    r'(?:open|read|show)\s+(?:news\s+)?\d{1,2}\b',
  ).hasMatch(lower);

  if (_index == 2 && numberedNewsCommand) {
    return false;
  }

  await _selectIndex(2);
  return true;
}
    if (nav && lower.contains('goal')) {
      await _selectIndex(3);
      return true;
    }
    if (nav && lower.contains('setting')) {
      await _selectIndex(4);
      return true;
    }
    return false;
  }

  Future<bool> _routeUnhandledVoiceToAssistant(String command) async {
    final opened = await _selectIndex(1);
    if (!opened) {
      await _voice.speak('The AI assistant is a premium feature. Your free dashboard and statement import are still available.');
      return true;
    }
    _assistantCommandBus.value = command;
    return true;
  }

  Widget _pageFor(int index) {
    final cached = _pageCache[index];
    if (cached != null) return cached;
    final page = switch (index) {
      0 => DashboardScreen(api: widget.api),
      1 => AssistantScreen(
          api: widget.api,
          voice: _voice,
          commandBus: _assistantCommandBus,
          goalsReload: _goalsReload,
          onPremiumRequired: _openPaywall,
        ),
      2 => NewsScreen(
          api: widget.api,
          voice: _voice,
          onPremiumRequired: _openPaywall,
        ),
      3 => GoalsScreen(
          api: widget.api,
          reloadSignal: _goalsReload,
          onPremiumRequired: _openPaywall,
        ),
      _ => SettingsScreen(
          themeService: widget.themeService,
          api: widget.api,
          voice: _voice,
          onOpenPaywall: _openPaywall,
          onSignedOut: widget.onSignedOut,
        ),
    };
    _pageCache[index] = page;
    return page;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _assistantCommandBus.dispose();
    _goalsReload.dispose();
    _voice.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const destinations = [
      NavigationDestination(icon: Icon(Icons.dashboard_rounded), label: 'Home'),
      NavigationDestination(icon: Icon(Icons.blur_circular_rounded), label: 'Assistant'),
      NavigationDestination(icon: Icon(Icons.newspaper_rounded), label: 'News'),
      NavigationDestination(icon: Icon(Icons.flag_rounded), label: 'Goals'),
      NavigationDestination(icon: Icon(Icons.settings_rounded), label: 'Settings'),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final expanded = constraints.maxWidth >= 900;
        _pageFor(_index);
        final content = IndexedStack(
          index: _index,
          children: List<Widget>.generate(
            5,
            (index) => _pageCache[index] ?? const SizedBox.shrink(),
          ),
        );
        if (expanded) {
          return Scaffold(
            body: SafeArea(
              child: Row(
                children: [
                  NavigationRail(
                    extended: constraints.maxWidth >= 1180,
                    selectedIndex: _index,
                    onDestinationSelected: _selectIndex,
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Icon(
                        Icons.auto_graph_rounded,
                        size: 34,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    destinations: const [
                      NavigationRailDestination(icon: Icon(Icons.dashboard_rounded), label: Text('Home')),
                      NavigationRailDestination(icon: Icon(Icons.blur_circular_rounded), label: Text('Assistant')),
                      NavigationRailDestination(icon: Icon(Icons.newspaper_rounded), label: Text('News')),
                      NavigationRailDestination(icon: Icon(Icons.flag_rounded), label: Text('Goals')),
                      NavigationRailDestination(icon: Icon(Icons.settings_rounded), label: Text('Settings')),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: content),
                ],
              ),
            ),
          );
        }
        return Scaffold(
          body: content,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _selectIndex,
            destinations: destinations,
          ),
        );
      },
    );
  }
}
