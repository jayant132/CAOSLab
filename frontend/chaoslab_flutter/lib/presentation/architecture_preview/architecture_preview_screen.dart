import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/architecture_graph.dart';
import '../../data/models/repository_inspect_result.dart';
import '../../viewmodels/architecture_preview_view_model.dart';
import '../shared/widgets/section_header.dart';
import '../simulation_config/simulation_config_screen.dart';

class ArchitecturePreviewScreen extends StatelessWidget {
  const ArchitecturePreviewScreen({super.key, required this.inspectResult});

  final RepositoryInspectResult inspectResult;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ArchitecturePreviewViewModel(inspectResult.architecture),
      child: _ArchitecturePreviewView(warnings: inspectResult.warnings),
    );
  }
}

class _ArchitecturePreviewView extends StatelessWidget {
  const _ArchitecturePreviewView({required this.warnings});

  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ArchitecturePreviewViewModel>();
    final architecture = vm.architecture;

    return Scaffold(
      appBar: AppBar(title: const Text('ARCHITECTURE')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                Icon(
                  architecture.usedFallback ? Icons.warning_amber_rounded : Icons.check_circle,
                  color: architecture.usedFallback ? AppColors.statusWarning : AppColors.statusHealthy,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    architecture.usedFallback
                        ? (architecture.fallbackReason ?? 'Using a reference architecture.')
                        : 'Parsed ${architecture.composeFilePath ?? "docker-compose.yml"} from ${architecture.repoFullName}',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ),
              ],
            ),
            if (warnings.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...warnings.map(
                (w) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('• $w', style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
                ),
              ),
            ],
            const SizedBox(height: 24),
            const SectionHeader(
              title: 'Services',
              subtitle: 'Adjust replica counts if the compose file doesn\'t reflect production scale.',
            ),
            ...architecture.services.map(
              (service) => _ServiceCard(
                service: service,
                onReplicasChanged: (value) => vm.updateReplicas(service.name, value),
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SimulationConfigScreen(architecture: architecture),
                    ),
                  );
                },
                child: const Text('CONFIGURE EXPERIMENT'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service, required this.onReplicasChanged});

  final ServiceNode service;
  final ValueChanged<int> onReplicasChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _RoleBadge(role: service.inferredRole),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    service.dependsOn.isEmpty
                        ? 'No declared dependencies'
                        : 'Depends on: ${service.dependsOn.join(", ")}',
                    style: const TextStyle(color: AppColors.textMuted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            _ReplicaStepper(
              value: service.replicas,
              onChanged: onReplicasChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final String role;

  IconData get _icon {
    switch (role) {
      case 'api':
        return Icons.dns_outlined;
      case 'database':
        return Icons.storage_outlined;
      case 'cache':
        return Icons.bolt_outlined;
      case 'queue':
        return Icons.swap_horiz;
      case 'gateway':
        return Icons.router_outlined;
      case 'worker':
        return Icons.settings_outlined;
      default:
        return Icons.widgets_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surfaceRaised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Icon(_icon, color: AppColors.accent, size: 20),
    );
  }
}

class _ReplicaStepper extends StatelessWidget {
  const _ReplicaStepper({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepperButton(icon: Icons.remove, onTap: value > 1 ? () => onChanged(value - 1) : null),
        SizedBox(
          width: 32,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
          ),
        ),
        _StepperButton(icon: Icons.add, onTap: () => onChanged(value + 1)),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 26,
        height: 26,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.border),
        ),
        child: Icon(
          icon,
          size: 14,
          color: onTap == null ? AppColors.textMuted : AppColors.textPrimary,
        ),
      ),
    );
  }
}
