import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/ai_sphere.dart';
import '../widgets/brand_mark.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.api,
    required this.onCompleted,
  });

  final ApiService api;
  final VoidCallback onCompleted;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _budget = TextEditingController();
  final _savings = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Enter your name to continue.');
      return;
    }
    final age = int.tryParse(_age.text.trim());
    if (_age.text.trim().isNotEmpty && age == null) {
      setState(() => _error = 'Age must be a whole number.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.api.saveProfile(
        displayName: _name.text.trim(),
        age: age,
        monthlyBudget: double.tryParse(_budget.text.trim()),
        savingsBalance: double.tryParse(_savings.text.trim()),
      );
      if (mounted) widget.onCompleted();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _budget.dispose();
    _savings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            final form = _form(context);
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 980),
                  child: wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(child: _hero(context)),
                            const SizedBox(width: 28),
                            Expanded(child: form),
                          ],
                        )
                      : Column(
                          children: [
                            _hero(context),
                            const SizedBox(height: 20),
                            form,
                          ],
                        ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _hero(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Align(alignment: Alignment.centerLeft, child: BrandMark()),
        const SizedBox(height: 24),
        const AiSphere(state: 'idle'),
        const SizedBox(height: 18),
        Text(
          'Welcome to WealthPilot.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          'Set up your private money profile once. Your dashboard and AI assistant will use it later when it is relevant.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _form(BuildContext context) {
    return Card(
      elevation: 10,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Let’s get started', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text('Your personal fields stay in your private profile and are not included in AI prompts.'),
            const SizedBox(height: 20),
            TextField(
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Your name', prefixIcon: Icon(Icons.person_outline_rounded)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _age,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Your age', prefixIcon: Icon(Icons.cake_outlined)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _budget,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Monthly budget (optional)', prefixIcon: Icon(Icons.account_balance_wallet_outlined)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _savings,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Current savings (optional)', prefixIcon: Icon(Icons.savings_outlined)),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _busy ? null : _save,
              icon: _busy
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.arrow_forward_rounded),
              label: Text(_busy ? 'Saving…' : 'Continue to my money snapshot'),
            ),
          ],
        ),
      ),
    );
  }
}
