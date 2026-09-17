import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/enums.dart';
import '../../../data/models/simulation_report.dart';

/// One row in the live agent-activity feed. This is the "oh, they get
/// agents" moment for a reviewer — each agent lights up as its event
/// arrives, so the hand-off between agents is visible in real time
/// instead of the whole pipeline resolving as one opaque spinner.
class AgentActivityRow extends StatelessWidget {
  const AgentActivityRow({super.key, required this.step, required this.isLatest});

  final AgentStepEvent step;
  final bool isLatest;

  IconData get _statusIcon => const {
        AgentStepStatus.complete: Icons.check_circle,
        AgentStepStatus.failed: Icons.error,
        AgentStepStatus.running: Icons.autorenew,
        AgentStepStatus.pending: Icons.schedule,
      }[step.status]!;

  Color get _statusColor => {
        AgentStepStatus.complete: AppColors.statusHealthy,
        AgentStepStatus.failed: AppColors.statusCritical,
        AgentStepStatus.running: AppColors.accent,
        AgentStepStatus.pending: AppColors.textMuted,
      }[step.status]!;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isLatest ? AppColors.accent.withOpacity(0.06) : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isLatest ? AppColors.accent.withOpacity(0.5) : AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_statusIcon, size: 18, color: _statusColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.agent.label,
                  style: AppTextStyles.eyebrow,
                ),
                const SizedBox(height: 3),
                Text(
                  step.headline,
                  style: AppTextStyles.cardTitle,
                ),
                if (step.detail != null && step.detail!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    step.detail!,
                    style: AppTextStyles.caption,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}