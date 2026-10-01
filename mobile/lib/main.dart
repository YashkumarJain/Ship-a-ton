import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/app_config.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/api_service.dart';
import 'services/revenuecat_service.dart';
import 'services/theme_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (AppConfig.supabaseConfigured) {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
    );
  }
  final themeService = ThemeService();
  await themeService.load();
  runApp(WealthPilotApp(themeService: themeService));
}

class WealthPilotApp extends StatefulWidget {
  const WealthPilotApp({super.key, required this.themeService});
  final ThemeService themeService;

  @override
  State<WealthPilotApp> createState() => _WealthPilotAppState();
}

class _WealthPilotAppState extends State<WealthPilotApp> {
  late final VoidCallback _themeListener;

  @override
  void initState() {
    super.initState();
    _themeListener = () => setState(() {});
    widget.themeService.addListener(_themeListener);
  }

  @override
  void dispose() {
    widget.themeService.removeListener(_themeListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF7C6CFF);
    final darkScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
      surface: const Color(0xFF0B1120),
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WealthPilot',
      themeMode: widget.themeService.mode,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
        ),
        cardTheme: const CardThemeData(clipBehavior: Clip.antiAlias),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: darkScheme,
        scaffoldBackgroundColor: const Color(0xFF070B14),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          centerTitle: false,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: const Color(0xFF0A1020),
          indicatorColor: darkScheme.primaryContainer.withValues(alpha: 0.7),
          height: 68,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF111827),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
        cardTheme: CardThemeData(
          clipBehavior: Clip.antiAlias,
          elevation: 0,
          color: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
          ),
        ),
      ),
      home: RootGate(themeService: widget.themeService),
    );
  }
}

class RootGate extends StatefulWidget {
  const RootGate({super.key, required this.themeService});
  final ThemeService themeService;

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  final _api = ApiService();
  final _revenueCat = RevenueCatService();
  StreamSubscription<AuthState>? _authSubscription;
  bool _demo = false;
  String? _configuredRevenueCatUser;

  @override
  void initState() {
    super.initState();
    if (AppConfig.supabaseConfigured) {
      _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((_) {
        if (mounted) setState(() {});
      });
    }
  }

  Future<void> _ensureRevenueCat(String appUserId) async {
    if (_configuredRevenueCatUser == appUserId) return;
    _configuredRevenueCatUser = appUserId;
    try {
      await _revenueCat.configure(appUserId: appUserId);
    } catch (error) {
      debugPrint('RevenueCat configuration failed: $error');
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = AppConfig.supabaseConfigured
        ? Supabase.instance.client.auth.currentSession
        : null;
    final signedIn = session != null || _demo;

    if (!signedIn) {
      return LoginScreen(onDemoContinue: () => setState(() => _demo = true));
    }

    final appUserId = session?.user.id ?? 'demo-user';
    _ensureRevenueCat(appUserId);

    return ProfileGate(
      api: _api,
      onSignedOut: () => setState(() => _demo = false),
      builder: () => HomeShell(
        api: _api,
        revenueCat: _revenueCat,
        themeService: widget.themeService,
        onSignedOut: () => setState(() => _demo = false),
      ),
    );
  }
}

class ProfileGate extends StatefulWidget {
  const ProfileGate({
    super.key,
    required this.api,
    required this.builder,
    required this.onSignedOut,
  });

  final ApiService api;
  final Widget Function() builder;
  final VoidCallback onSignedOut;

  @override
  State<ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<ProfileGate> {
  bool _loading = true;
  bool _complete = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await widget.api.profile();
      if (mounted) setState(() => _complete = profile.onboardingComplete);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 54),
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 14),
                FilledButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }
    if (!_complete) {
      return OnboardingScreen(
        api: widget.api,
        onCompleted: () => setState(() => _complete = true),
      );
    }
    return widget.builder();
  }
}
