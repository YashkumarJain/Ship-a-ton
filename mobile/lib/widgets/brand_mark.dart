import 'package:flutter/material.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 28 : 34,
          height: compact ? 28 : 34,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: const LinearGradient(
              colors: [Color(0xFF1C8DFF), Color(0xFF7A5CFA), Color(0xFFD45CFF)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4EA7FF).withValues(alpha: 0.35),
                blurRadius: 16,
              ),
            ],
          ),
          child: Icon(Icons.auto_graph_rounded, size: compact ? 16 : 19, color: Colors.white),
        ),
        const SizedBox(width: 9),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'WEALTHPILOT',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
            ),
            if (!compact)
              Text(
                'your AI Wealth Assistant',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
          ],
        ),
      ],
    );
  }
}
