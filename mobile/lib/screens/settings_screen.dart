import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import '../services/api_service.dart';
import '../services/theme_service.dart';
import '../services/voice_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.themeService,
    required this.api,
    required this.voice,
    required this.onOpenPaywall,
    required this.onSignedOut,
  });

  final ThemeService themeService;
  final ApiService api;
  final VoiceService voice;
  final VoidCallback onOpenPaywall;
  final VoidCallback onSignedOut;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, dynamic>? _subscription;

  @override
  void initState() {
    super.initState();
    widget.voice.addListener(_voiceChanged);
    _load();
  }

  void _voiceChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    try {
      final value = await widget.api.subscriptionStatus();
      if (mounted) setState(() => _subscription = value);
    } catch (_) {}
  }

  @override
  void dispose() {
    widget.voice.removeListener(_voiceChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mode = widget.themeService.mode;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
      children: [
        Text('Settings', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Appearance', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto_rounded), label: Text('System')),
                    ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_rounded), label: Text('Light')),
                    ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_rounded), label: Text('Dark')),
                  ],
                  selected: {mode},
                  onSelectionChanged: (set) => widget.themeService.setMode(set.first),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: SwitchListTile(
            secondary: Icon(widget.voice.enabled ? Icons.mic_rounded : Icons.mic_off_rounded),
            title: const Text('“Hey Wealth Assistant” wake phrase'),
            subtitle: const Text('Listens only while the app is open. Works from any main screen.'),
            value: widget.voice.enabled,
            onChanged: widget.voice.setEnabled,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.workspace_premium_rounded),
            title: Text('Access: ${_subscription?['status'] ?? 'checking…'}'),
            subtitle: _subscription?['trialEndsAt'] != null
                ? Text('Trial ends ${_subscription!['trialEndsAt']}')
                : const Text('Free dashboard + statement import. Premium AI features: 6-day trial, then \$4.99/month.'),
            trailing: FilledButton.tonal(
              onPressed: widget.onOpenPaywall,
              child: const Text('Manage'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Privacy', style: TextStyle(fontWeight: FontWeight.w800)),
                SizedBox(height: 8),
                Text(
                  'Your profile and financial rows are isolated by Supabase Row Level Security. Uploaded PDFs are processed in memory and not retained. Only transactions you approve are saved. AI prompts exclude names, emails, account/card details, user IDs, transaction IDs and merchant names; the model receives only the anonymous financial values needed for analysis.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () async {
            if (AppConfig.supabaseConfigured) {
              await Supabase.instance.client.auth.signOut();
            }
            widget.onSignedOut();
          },
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Sign out'),
        ),
      ],
    );
  }
}
