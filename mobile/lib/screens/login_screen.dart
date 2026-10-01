import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import '../widgets/brand_mark.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.onDemoContinue});
  final VoidCallback onDemoContinue;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signUp = false;
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (!AppConfig.supabaseConfigured) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_signUp) {
        await Supabase.instance.client.auth.signUp(
          email: _email.text.trim(),
          password: _password.text,
        );
      } else {
        await Supabase.instance.client.auth.signInWithPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
    } on AuthException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                elevation: 12,
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: BrandMark()),
                      const SizedBox(height: 18),
                      Icon(
                        Icons.blur_circular_rounded,
                        size: 54,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Welcome back',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'WealthPilot — your AI Wealth Assistant',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 24),
                      if (AppConfig.supabaseConfigured) ...[
                        TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _password,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                        ],
                        const SizedBox(height: 18),
                        FilledButton(
                          onPressed: _busy ? null : _submit,
                          child: Text(_busy
                              ? 'Please wait…'
                              : _signUp
                                  ? 'Create account'
                                  : 'Sign in'),
                        ),
                        TextButton(
                          onPressed: _busy ? null : () => setState(() => _signUp = !_signUp),
                          child: Text(_signUp
                              ? 'Already have an account? Sign in'
                              : 'New here? Create an account'),
                        ),
                      ] else ...[
                        const Text(
                          'Supabase is not configured in this build. Continue in local demo mode to preview the app.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 18),
                        FilledButton.icon(
                          onPressed: widget.onDemoContinue,
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Continue in demo mode'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
