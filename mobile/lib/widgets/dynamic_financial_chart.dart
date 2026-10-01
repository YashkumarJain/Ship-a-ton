import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/assistant_response.dart';

class DynamicFinancialChart extends StatefulWidget {
  const DynamicFinancialChart({
    super.key,
    required this.spec,
    required this.animateHighlight,
    this.highlightLabel,
  });

  final VisualizationSpec? spec;
  final bool animateHighlight;
  final String? highlightLabel;

  @override
  State<DynamicFinancialChart> createState() =>
      _DynamicFinancialChartState();
}

class _DynamicFinancialChartState extends State<DynamicFinancialChart> {
  String? get _highlightLabel {
    if (!widget.animateHighlight) return null;
    final label = widget.highlightLabel?.trim();
    if (label == null || label.isEmpty) return null;
    return label;
  }


  @override
  Widget build(BuildContext context) {
    final spec = widget.spec;
    if (spec == null || spec.series.isEmpty) {
      return _empty(context);
    }

    return Card(
      elevation: 10,
      shadowColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.22),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(spec.title, style: Theme.of(context).textTheme.titleLarge),
            if (spec.subtitle != null) ...[
              const SizedBox(height: 4),
              Text(spec.subtitle!, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            Expanded(child: _chart(context, spec)),
          ],
        ),
      ),
    );
  }

  Widget _chart(BuildContext context, VisualizationSpec spec) {
    switch (spec.type) {
      case 'donut':
        return _donut(context, spec);
      case 'comparison_bar':
        return _bars(context, spec, comparison: true);
      case 'progress':
      case 'goal':
        return _progress(context, spec);
      default:
        return _bars(context, spec);
    }
  }

  Widget _bars(
    BuildContext context,
    VisualizationSpec spec, {
    bool comparison = false,
  }) {
    final theme = Theme.of(context);
    final maxAbs = spec.series.fold<double>(1, (value, point) {
      final a = point.value.abs();
      final b = point.secondaryValue?.abs() ?? 0;
      return math.max(value, math.max(a, b));
    });
    final minY = spec.series.any((p) => p.value < 0) ? -maxAbs * 1.25 : 0.0;
    final maxY = maxAbs * 1.35;

    return BarChart(
      BarChartData(
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: theme.dividerColor.withValues(alpha: 0.18),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 42,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= spec.series.length) return const SizedBox();
                final label = spec.series[index].label;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    label.length > 10 ? '${label.substring(0, 9)}…' : label,
                    style: theme.textTheme.labelSmall,
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var i = 0; i < spec.series.length; i++)
            BarChartGroupData(
              x: i,
              barsSpace: 4,
              barRods: [
                _rod(context, spec.series[i].value, spec.series[i].label),
                if (comparison && spec.series[i].secondaryValue != null)
                  _rod(
                    context,
                    spec.series[i].secondaryValue!,
                    spec.series[i].label,
                    secondary: true,
                  ),
              ],
            ),
        ],
      ),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
    );
  }

  BarChartRodData _rod(
    BuildContext context,
    double value,
    String label, {
    bool secondary = false,
  }) {
    final selected = _highlightLabel == label;
    final colors = secondary
        ? [const Color(0xFF39D6C5), const Color(0xFF4EA7FF)]
        : [const Color(0xFF7A5CFA), const Color(0xFFD45CFF)];
    return BarChartRodData(
      toY: value,
      width: selected ? 20 : 14,
      borderRadius: BorderRadius.circular(7),
      gradient: LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: colors
            .map((color) => color.withValues(alpha: selected ? 1 : 0.68))
            .toList(),
      ),
      backDrawRodData: BackgroundBarChartRodData(
        show: true,
        toY: value >= 0 ? value * 1.04 : value * 1.04,
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
      ),
    );
  }

  Widget _donut(BuildContext context, VisualizationSpec spec) {
    const palette = [
      Color(0xFF7A5CFA),
      Color(0xFF4EA7FF),
      Color(0xFFD45CFF),
      Color(0xFF39D6C5),
      Color(0xFFFFB454),
      Color(0xFFFF6B8A),
      Color(0xFF75D26B),
      Color(0xFF8A8FFF),
    ];
    return PieChart(
      PieChartData(
        centerSpaceRadius: 50,
        sectionsSpace: 3,
        sections: [
          for (var i = 0; i < spec.series.length; i++)
            PieChartSectionData(
              value: spec.series[i].value.abs(),
              color: palette[i % palette.length],
              radius: _highlightLabel == spec.series[i].label ? 72 : 62,
              title: spec.series[i].label,
              titleStyle: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _progress(BuildContext context, VisualizationSpec spec) {
    final maxValue = spec.series.fold<double>(1, (m, p) => math.max(m, p.value));
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: spec.series.length,
      separatorBuilder: (_, __) => const SizedBox(height: 18),
      itemBuilder: (context, index) {
        final point = spec.series[index];
        final selected = _highlightLabel == point.label;
        return AnimatedScale(
          scale: selected ? 1.025 : 1,
          duration: const Duration(milliseconds: 300),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(point.label),
                  Text('\$${point.value.toStringAsFixed(0)}'),
                ],
              ),
              const SizedBox(height: 8),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: (point.value / maxValue).clamp(0.0, 1.0).toDouble()),
                duration: const Duration(milliseconds: 700),
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: selected ? 18 : 13,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _empty(BuildContext context) {
    return Card(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_graph_rounded,
                  size: 48, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 12),
              const Text(
                'Ask a financial question and the chart will adapt to the evidence used in the answer.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
