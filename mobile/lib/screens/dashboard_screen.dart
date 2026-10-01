import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models/dashboard_data.dart';
import '../services/api_service.dart';
import '../widgets/brand_mark.dart';
import 'statement_review_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.api});
  final ApiService api;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardData? _data;
  bool _loading = true;
  bool _uploading = false;
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
      final data = await widget.api.dashboard();
      if (mounted) setState(() => _data = data);
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickStatement() async {
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        withData: true,
      );
      if (picked == null || picked.files.isEmpty) return;
      final file = picked.files.single;
      if (file.size > 12 * 1024 * 1024) throw ApiException('PDF must be 12 MB or smaller.');
      final bytes = file.bytes;
      if (bytes == null) throw ApiException('Could not read the selected PDF.');
      final result = await widget.api.parseStatement(bytes: bytes, filename: file.name);
      if (!mounted) return;
      final saved = await Navigator.of(context).push<Map<String, dynamic>>(
        MaterialPageRoute(
          builder: (_) => StatementReviewScreen(api: widget.api, result: result),
        ),
      );
      if (saved != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${saved['saved'] ?? 0} new transactions saved • ${saved['duplicatesSkipped'] ?? 0} already-saved matches skipped.')),
        );
        await _load();
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _load,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 820;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 120),
            children: [
              Row(
                children: [
                  const BrandMark(compact: true),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Refresh',
                    onPressed: _loading ? null : _load,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 4, child: _welcome(context)),
                    const SizedBox(width: 16),
                    Expanded(flex: 6, child: _statementCard(context)),
                  ],
                )
              else ...[
                _welcome(context),
                const SizedBox(height: 14),
                _statementCard(context),
              ],
              const SizedBox(height: 18),
              if (_loading)
                const Center(child: Padding(padding: EdgeInsets.all(28), child: CircularProgressIndicator()))
              else if (_error != null)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ),
                )
              else if (_data != null)
                _snapshot(context, _data!),
            ],
          );
        },
      ),
    );
  }

  Widget _welcome(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.account_balance_wallet_outlined,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 14),
            Text(
              'Your money, simplified.',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Upload a statement, review the rows, and WealthPilot keeps only new transactions.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statementCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Import statement', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(
              'PDF only • reviewed before saving • original file is not kept',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _uploading ? null : _pickStatement,
              icon: _uploading
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.picture_as_pdf_rounded),
              label: Text(_uploading ? 'Reading statement…' : 'Choose PDF'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _snapshot(BuildContext context, DashboardData data) {
    final s = data.snapshot;
    final cards = [
      ('Money in', '\$${s.moneyIn.toStringAsFixed(2)}', Icons.south_west_rounded),
      ('Money out', '\$${s.moneyOut.toStringAsFixed(2)}', Icons.north_east_rounded),
      ('Activity found', '${s.activityFound}', Icons.receipt_long_outlined),
      ('Largest category', s.largestCategory, Icons.donut_large_rounded),
    ];
    return Card(
      elevation: 9,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Your money snapshot', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(data.periodLabel, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 700 ? 4 : 2;
                final width = (constraints.maxWidth - (columns - 1) * 10) / columns;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final item in cards)
                      SizedBox(
                        width: width,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(item.$3, size: 20, color: Theme.of(context).colorScheme.primary),
                              const SizedBox(height: 10),
                              Text(item.$1, style: Theme.of(context).textTheme.labelMedium),
                              const SizedBox(height: 3),
                              Text(item.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),
            Text('Where your money went', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            if (data.categories.isEmpty)
              const Text('Upload a statement to build your category snapshot.')
            else
              for (final category in data.categories)
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.32),
                      border: Border(left: BorderSide(color: Theme.of(context).colorScheme.primary, width: 3)),
                    ),
                    child: Row(
                      children: [
                        Expanded(child: Text(category.category)),
                        Text('\$${category.amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
