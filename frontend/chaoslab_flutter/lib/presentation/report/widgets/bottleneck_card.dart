import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/simulation_metrics.dart';

class BottleneckCard extends StatelessWidget {
  const BottleneckCard({super.key, required this.finding, required this.isTop});

  final BottleneckFinding finding;
  final bool isTop;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.riskColor(finding.riskScorePct);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withOpacity(0.5)),
              ),
              child: Text(
                '${finding.riskScorePct.round()}%',
                style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        finding.serviceName,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (isTop) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.statusCritical.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'BREAKS FIRST',
                            style: TextStyle(
                              color: AppColors.statusCritical,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    finding.reasoning,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.45),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
