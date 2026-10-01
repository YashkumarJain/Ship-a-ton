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
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth.isFinite ? constraints.maxWidth : 170.0;
        final height = constraints.maxHeight.isFinite ? constraints.maxHeight : 170.0;
        final available = math.min(width, height);
        final base = (available * 0.7).clamp(68.0, 132.0).toDouble();
        final inner = base * 0.61;
        final ringBase = base * 1.22;

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final t = _controller.value;
            final active = widget.state != 'idle';
            final pulse = active ? 1 + math.sin(t * math.pi * 2) * 0.055 : 1.0;
            final speaking = widget.state == 'speaking';
            final ringPulse = speaking ? base * 0.12 * math.sin(t * math.pi * 2).abs() : 0.0;
            return Center(
              child: Transform.scale(
                scale: pulse,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    if (active)
                      Container(
                        width: ringBase + ringPulse,
                        height: ringBase + ringPulse,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.purpleAccent.withValues(alpha: 0.28),
                            width: 2,
                          ),
                        ),
                      ),
                    Container(
                      width: base,
                      height: base,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: SweepGradient(
                          transform: GradientRotation(t * math.pi * 2),
                          colors: const [
                            Color(0xFF1C8DFF),
                            Color(0xFF7A5CFA),
                            Color(0xFFD45CFF),
                            Color(0xFF33E6FF),
                            Color(0xFF1C8DFF),
                          ],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF7A5CFA).withValues(alpha: active ? 0.55 : 0.28),
                            blurRadius: active ? base * 0.26 : base * 0.15,
                            spreadRadius: active ? base * 0.04 : 1,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Container(
                          width: inner,
                          height: inner,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Colors.white.withValues(alpha: 0.75),
                                const Color(0xFF6D5DFB).withValues(alpha: 0.45),
                                const Color(0xFF07101F).withValues(alpha: 0.92),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
