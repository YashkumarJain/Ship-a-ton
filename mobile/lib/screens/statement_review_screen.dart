import 'package:flutter/material.dart';
import '../models/statement_import.dart';
import '../services/api_service.dart';

class StatementReviewScreen extends StatefulWidget {
  const StatementReviewScreen({
    super.key,
    required this.api,
    required this.result,
  });

  final ApiService api;
  final StatementImportResult result;

  @override
  State<StatementReviewScreen> createState() => _StatementReviewScreenState();
}

class _StatementReviewScreenState extends State<StatementReviewScreen> {
  late final List<StatementTransaction> _transactions;
  bool _saving = false;
  String? _error;

  static const _categories = [
    'Rent', 'Groceries', 'Dining', 'Transport', 'Travel', 'Shopping',
    'Subscriptions', 'Utilities', 'Fitness', 'Healthcare', 'Education',
    'Insurance', 'Income', 'Other'
  ];

  @override
  void initState() {
    super.initState();
    _transactions = [...widget.result.transactions];
  }


  Future<void> _add() async {
    final merchant = TextEditingController();
    final amount = TextEditingController();
    final date = TextEditingController();
    var category = 'Other';
    var type = 'expense';

    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add transaction'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: date, decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)')),
                const SizedBox(height: 10),
                TextField(controller: merchant, decoration: const InputDecoration(labelText: 'Merchant / description')),
                const SizedBox(height: 10),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: _categories.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                  onChanged: (value) => setDialogState(() => category = value ?? category),
                ),
                const SizedBox(height: 10),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'expense', label: Text('Expense')),
                    ButtonSegment(value: 'income', label: Text('Income')),
                  ],
                  selected: {type},
                  onSelectionChanged: (value) => setDialogState(() => type = value.first),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
          ],
        ),
      ),
    );

    if (approved == true) {
      final parsedAmount = double.tryParse(amount.text.trim());
      if (parsedAmount != null && parsedAmount > 0 && merchant.text.trim().isNotEmpty && date.text.trim().isNotEmpty) {
        setState(() {
          _transactions.add(StatementTransaction(
            date: date.text.trim(),
            merchant: merchant.text.trim(),
            category: category,
            amount: parsedAmount,
            type: type,
            confidence: 1,
            fingerprint: '',
            sourceOccurrence: 1,
          ));
        });
      }
    }
    merchant.dispose();
    amount.dispose();
    date.dispose();
  }

  Future<void> _edit(int index) async {
    final transaction = _transactions[index];
    final merchant = TextEditingController(text: transaction.merchant);
    final amount = TextEditingController(text: transaction.amount.toStringAsFixed(2));
    final date = TextEditingController(text: transaction.date);
    var category = _categories.contains(transaction.category) ? transaction.category : 'Other';
    var type = transaction.type;

    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Review transaction'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: date, decoration: const InputDecoration(labelText: 'Date (YYYY-MM-DD)')),
                const SizedBox(height: 10),
                TextField(controller: merchant, decoration: const InputDecoration(labelText: 'Merchant / description')),
                const SizedBox(height: 10),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Amount'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: _categories.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                  onChanged: (value) => setDialogState(() => category = value ?? category),
                ),
                const SizedBox(height: 10),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'expense', label: Text('Expense')),
                    ButtonSegment(value: 'income', label: Text('Income')),
                  ],
                  selected: {type},
                  onSelectionChanged: (value) => setDialogState(() => type = value.first),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save change')),
          ],
        ),
      ),
    );

    if (approved == true) {
      final parsedAmount = double.tryParse(amount.text.trim());
      if (parsedAmount == null || parsedAmount <= 0) return;
      setState(() {
        transaction.date = date.text.trim();
        transaction.merchant = merchant.text.trim();
        transaction.amount = parsedAmount;
        transaction.category = category;
        transaction.type = type;
      });
    }
    merchant.dispose();
    amount.dispose();
    date.dispose();
  }

  Future<void> _save() async {
    if (_transactions.isEmpty) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save these transactions?'),
        content: Text(
          'You reviewed ${_transactions.length} transactions. The original PDF will not be stored. New transactions will be appended to your private history; matches already saved from earlier statements will be skipped automatically and will not overwrite your previous categories or data.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Review again')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Approve & save')),
        ],
      ),
    );
    if (approved != true) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await widget.api.commitStatement(_transactions);
      if (!mounted) return;
      Navigator.pop(context, result);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review statement import'),
        actions: [IconButton(onPressed: _add, icon: const Icon(Icons.add_rounded), tooltip: 'Add transaction')],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _summaryPill(
                              context,
                              '${widget.result.newCount}',
                              'new',
                              Icons.add_circle_outline_rounded,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _summaryPill(
                              context,
                              '${widget.result.overlapCount}',
                              'overlap',
                              Icons.content_copy_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '${_transactions.length} rows to review • PDF not stored',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                      ),
                      for (final warning in widget.result.warnings.take(1))
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text('• $warning', style: TextStyle(color: Theme.of(context).colorScheme.tertiary)),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                itemCount: _transactions.length,
                itemBuilder: (context, index) {
                  final item = _transactions[index];
                  return Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Icon(item.type == 'income' ? Icons.south_west_rounded : Icons.north_east_rounded),
                      ),
                      title: Text(item.merchant, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${item.date} • ${item.category} • confidence ${(item.confidence * 100).round()}%'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${item.type == 'income' ? '+' : '-'}\$${item.amount.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          IconButton(onPressed: () => _edit(index), icon: const Icon(Icons.edit_outlined)),
                          IconButton(
                            onPressed: () => setState(() => _transactions.removeAt(index)),
                            icon: const Icon(Icons.close_rounded),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.paddingOf(context).bottom + 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _saving || _transactions.isEmpty ? null : _save,
                  icon: _saving
                      ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check_circle_outline_rounded),
                  label: Text(_saving ? 'Saving…' : 'Approve & save ${_transactions.length} transactions'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryPill(
    BuildContext context,
    String value,
    String label,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(width: 5),
          Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}
