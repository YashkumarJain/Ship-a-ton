import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../services/api_service.dart';
import '../services/revenuecat_service.dart';

class PaywallScreen extends StatefulWidget {
  const PaywallScreen({
    super.key,
    required this.revenueCat,
    required this.api,
    this.onUnlocked,
  });

  final RevenueCatService revenueCat;
  final ApiService api;
  final VoidCallback? onUnlocked;

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  Package? _package;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!widget.revenueCat.configured) return;
    final package = await widget.revenueCat.currentPackage();
    if (mounted) setState(() => _package = package);
  }

  Future<void> _purchase() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      bool unlocked = false;
      if (widget.revenueCat.configured && _package != null) {
        unlocked = await widget.revenueCat.purchase(_package!);
      } else {
        final result = await widget.api.simulatePremium();
        unlocked = result['access'] == true;
      }
      if (!mounted) return;
      setState(() => _message = unlocked ? 'Premium unlocked.' : 'Purchase was not completed.');
      if (unlocked) widget.onUnlocked?.call();
    } catch (error) {
      if (mounted) setState(() => _message = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore() async {
    if (!widget.revenueCat.configured) return;
    setState(() => _busy = true);
    try {
      final unlocked = await widget.revenueCat.restore();
      if (!mounted) return;
      setState(() => _message = unlocked ? 'Purchase restored.' : 'No active premium entitlement found.');
      if (unlocked) widget.onUnlocked?.call();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final price = _package?.storeProduct.priceString ?? r'$4.99 / month';
    return Scaffold(
      appBar: AppBar(title: const Text('WealthPilot Premium')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Card(
              elevation: 12,
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    Icon(Icons.workspace_premium_rounded,
                        size: 68, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      'Unlock your AI Wealth Assistant',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Your free plan keeps statement upload, categorization and the money snapshot. Premium adds the voice AI assistant, advanced analysis, adaptive charts, goals and verified-news analysis.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    const _FeatureRow(icon: Icons.mic_rounded, text: '“Hey Wealth Assistant” voice experience'),
                    const _FeatureRow(icon: Icons.auto_graph_rounded, text: 'Multi-step financial analysis + adaptive charts'),
                    const _FeatureRow(icon: Icons.flag_rounded, text: 'Goal and vacation planning with approval controls'),
                    const _FeatureRow(icon: Icons.newspaper_rounded, text: 'Top verified industry news + spoken overviews'),
                    const SizedBox(height: 20),
                    Text(price, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 6),
                    const Text('Includes a 6-day trial for new users.', textAlign: TextAlign.center),
                    const SizedBox(height: 4),
                    Text(
                      widget.revenueCat.configured
                          ? 'Purchases are powered by RevenueCat.'
                          : 'Development fallback is active. Configure RevenueCat Test Store for the hackathon demo and production store keys before release.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 12),
                      Text(_message!, textAlign: TextAlign.center),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _busy ? null : _purchase,
                        icon: const Icon(Icons.lock_open_rounded),
                        label: Text(_busy ? 'Working…' : 'Continue for $price'),
                      ),
                    ),
                    if (widget.revenueCat.configured)
                      TextButton(
                        onPressed: _busy ? null : _restore,
                        child: const Text('Restore purchases'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon, size: 19, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
