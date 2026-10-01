import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../models/financial_goal.dart';
import '../services/api_service.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({
    super.key,
    required this.api,
    required this.onPremiumRequired,
    required this.reloadSignal,
  });

  final ApiService api;
  final VoidCallback onPremiumRequired;
  final ValueListenable<int> reloadSignal;

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  List<FinancialGoal> _goals = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.reloadSignal.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    widget.reloadSignal.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final goals = await widget.api.goals();
      if (mounted) setState(() => _goals = goals);
    } on ApiException catch (error) {
      if (error.statusCode == 402) widget.onPremiumRequired();
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createOrEdit([FinancialGoal? existing]) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final amount = TextEditingController(text: existing == null ? '' : existing.targetAmount.toStringAsFixed(0));
    final date = TextEditingController(text: existing?.targetDate ?? '');
    var type = existing?.goalType ?? 'savings';

    final draft = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'New goal' : 'Edit goal'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Goal name')),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(labelText: 'Goal type'),
                  items: const [
                    DropdownMenuItem(value: 'savings', child: Text('Savings')),
                    DropdownMenuItem(value: 'vacation', child: Text('Vacation')),
                    DropdownMenuItem(value: 'emergency_fund', child: Text('Emergency fund')),
                    DropdownMenuItem(value: 'purchase', child: Text('Major purchase')),
                  ],
                  onChanged: (value) => setDialogState(() => type = value ?? type),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Target amount'),
                ),
                const SizedBox(height: 10),
                TextField(controller: date, decoration: const InputDecoration(labelText: 'Target date (YYYY-MM-DD)')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final parsed = double.tryParse(amount.text.trim());
                if (name.text.trim().isEmpty || parsed == null || parsed < 0) return;
                Navigator.pop(context, {
                  'name': name.text.trim(),
                  'goalType': type,
                  'targetAmount': parsed,
                  'targetDate': date.text.trim().isEmpty ? null : date.text.trim(),
                });
              },
              child: const Text('Review'),
            ),
          ],
        ),
      ),
    );

    name.dispose();
    amount.dispose();
    date.dispose();
    if (draft == null || !mounted) return;

    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(existing == null ? 'Create this goal?' : 'Apply this change?'),
        content: Text(
          '${draft['name']} • \$${(draft['targetAmount'] as double).toStringAsFixed(0)}'
          '${draft['targetDate'] != null ? ' • ${draft['targetDate']}' : ''}\n\nWealthPilot will not change your goals without this approval.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Approve')),
        ],
      ),
    );
    if (approved != true) return;

    try {
      if (existing == null) {
        await widget.api.createGoal(
          name: draft['name'] as String,
          goalType: draft['goalType'] as String,
          targetAmount: draft['targetAmount'] as double,
          targetDate: draft['targetDate'] as String?,
        );
      } else {
        await widget.api.updateGoal(FinancialGoal(
          id: existing.id,
          name: draft['name'] as String,
          goalType: draft['goalType'] as String,
          targetAmount: draft['targetAmount'] as double,
          targetDate: draft['targetDate'] as String?,
          isActive: existing.isActive,
        ));
      }
      await _load();
    } on ApiException catch (error) {
      if (error.statusCode == 402) widget.onPremiumRequired();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  Future<void> _delete(FinancialGoal goal) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this goal?'),
        content: Text('Delete “${goal.name}”? WealthPilot will only do this after you approve.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep it')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Approve delete')),
        ],
      ),
    );
    if (approved != true) return;
    try {
      await widget.api.deleteGoal(goal.id);
      await _load();
    } on ApiException catch (error) {
      if (error.statusCode == 402) widget.onPremiumRequired();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Goals'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createOrEdit(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New goal'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
              : _goals.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.flag_outlined, size: 60, color: Theme.of(context).colorScheme.primary),
                            const SizedBox(height: 14),
                            Text('Plan something worth saving for', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                            const SizedBox(height: 8),
                            const Text('Create a vacation, savings, emergency-fund or purchase goal. The AI can also propose a goal, but you always approve it before it is saved.', textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 110),
                      itemCount: _goals.length,
                      itemBuilder: (context, index) {
                        final goal = _goals[index];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Icon(goal.goalType == 'vacation' ? Icons.flight_takeoff_rounded : Icons.flag_rounded),
                            ),
                            title: Text(goal.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                            subtitle: Text('${goal.goalType.replaceAll('_', ' ')}${goal.targetDate != null ? ' • ${goal.targetDate}' : ''}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('\$${goal.targetAmount.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w900)),
                                PopupMenuButton<String>(
                                  onSelected: (value) => value == 'edit' ? _createOrEdit(goal) : _delete(goal),
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(value: 'edit', child: Text('Edit')),
                                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
