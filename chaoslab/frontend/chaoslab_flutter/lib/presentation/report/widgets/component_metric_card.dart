import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/simulation_metrics.dart';
import '../../shared/widgets/metric_bar.dart';

class ComponentMetricCard extends StatelessWidget {
  const ComponentMetricCard({super.key, required this.metric});

  final ComponentMetric metric;

  @override
  Widget build(BuildContext context) {
    final riskColor = AppColors.riskColor(metric.riskScorePct);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    metric.serviceName,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: riskColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'RISK ${metric.riskScorePct.round()}%',
                    style: TextStyle(color: riskColor, fontSize: 10.5, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            MetricBar(
              label: 'CPU utilization',
              valueLabel: '${metric.cpuUtilizationPct.toStringAsFixed(0)}%',
              fraction: metric.cpuUtilizationPct / 100,
              color: AppColors.riskColor(metric.cpuUtilizationPct),
            ),
            const SizedBox(height: 10),
            MetricBar(
              label: 'p95 latency',
              valueLabel: '${metric.p95LatencyMs.toStringAsFixed(0)} ms',
              fraction: (metric.p95LatencyMs / 5000).clamp(0.0, 1.0),
              color: AppColors.accent,
            ),
            const SizedBox(height: 10),
            MetricBar(
              label: 'Error rate',
              valueLabel: '${metric.errorRatePct.toStringAsFixed(1)}%',
              fraction: metric.errorRatePct / 100,
              color: AppColors.riskColor(metric.errorRatePct * 2),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.dns_outlined, size: 14, color: AppColors.textMuted),
                const SizedBox(width: 6),
                Text(
                  'Recommended fleet size: ${metric.instancesRequired} instance${metric.instancesRequired == 1 ? "" : "s"}',
                  style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
