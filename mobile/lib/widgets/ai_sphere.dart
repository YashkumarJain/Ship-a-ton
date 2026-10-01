import 'dart:math' as math;
import 'package:flutter/material.dart';

class AiSphere extends StatefulWidget {
  const AiSphere({super.key, required this.state});
  final String state;

  @override
  State<AiSphere> createState() => _AiSphereState();
}

class _AiSphereState extends State<AiSphere>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 96.0;
        final height = constraints.maxHeight.isFinite ? constraints.maxHeight : 96.0;
        final size = math.min(width, height).clamp(48.0, 104.0).toDouble();
        final active = widget.state != 'idle' && widget.state != 'unavailable';

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final wave = active
                ? 1 + math.sin(_controller.value * math.pi * 2) * 0.035
                : 1.0;
            return Center(
              child: Transform.scale(
                scale: wave,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: colors.primary.withValues(alpha: active ? 0.55 : 0.22),
                    ),
                    gradient: RadialGradient(
                      colors: [
                        colors.primary.withValues(alpha: active ? 0.28 : 0.14),
                        colors.surfaceContainerHighest.withValues(alpha: 0.92),
                      ],
                    ),
                    boxShadow: active
                        ? [
                            BoxShadow(
                              color: colors.primary.withValues(alpha: 0.18),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ]
                        : const [],
                  ),
                  child: Icon(
                    widget.state == 'speaking'
                        ? Icons.graphic_eq_rounded
                        : widget.state == 'listening'
                            ? Icons.mic_none_rounded
                            : widget.state == 'thinking'
                                ? Icons.auto_awesome_rounded
                                : Icons.auto_graph_rounded,
                    size: size * 0.34,
                    color: widget.state == 'unavailable'
                        ? colors.error
                        : colors.primary,
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
