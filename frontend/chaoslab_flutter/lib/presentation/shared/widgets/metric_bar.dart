import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// A horizontal fill bar used for CPU/latency/risk metrics throughout the
/// live and report screens. Color is driven by [riskColor] so the same
/// widget reads consistently as "healthy / warning / critical" everywhere.
class MetricBar extends StatelessWidget {
  const MetricBar({
    super.key,
    required this.label,
    required this.valueLabel,
    required this.fraction,
    this.color,
  });

  final String label;
  final String valueLabel;
  final double fraction; // 0.0 - 1.0+ (values above 1 are clamped visually)
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final clamped = fraction.clamp(0.0, 1.0);
    final barColor = color ?? AppColors.accent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            Text(
              valueLabel,
              style: TextStyle(color: barColor, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Container(height: 8, color: AppColors.border),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    height: 8,
                    width: constraints.maxWidth * clamped,
                    color: barColor,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
