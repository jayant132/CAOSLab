import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/enums.dart';

/// Static overview of the 4-stage pipeline shown above the live activity
/// feed, so a viewer understands the whole shape of the system in the
/// first second — not just whichever step happens to have streamed in so
/// far. Each stage lights up once its first event has arrived.
class AgentPipelineLegend extends StatelessWidget {
  const AgentPipelineLegend({super.key, required this.reachedAgents});

  /// Agents that have emitted at least one step event so far.
  final Set<AgentName> reachedAgents;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
      margin: const EdgeInsets.fromLTRB(AppSpacing.xl, 0, AppSpacing.xl, AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          for (final agent in AgentName.values) ...[
            Expanded(child: _StageDot(agent: agent, reached: reachedAgents.contains(agent))),
            if (agent != AgentName.values.last)
              Container(
                width: 16,
                height: 1,
                color: AppColors.border,
              ),
          ],
        ],
      ),
    );
  }
}

class _StageDot extends StatelessWidget {
  const _StageDot({required this.agent, required this.reached});

  final AgentName agent;
  final bool reached;

  @override
  Widget build(BuildContext context) {
    final color = reached ? AppColors.accent : AppColors.textMuted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(height: 6),
        Text(
          agent.label,
          style: TextStyle(color: color, fontSize: 10.5, fontWeight: FontWeight.w700),
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          agent.subtitle,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 9.5),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
