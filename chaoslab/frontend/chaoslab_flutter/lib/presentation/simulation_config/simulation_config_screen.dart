import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/di/service_locator.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/view_state.dart';
import '../../data/models/architecture_graph.dart';
import '../../data/models/enums.dart';
import '../../viewmodels/simulation_config_view_model.dart';
import '../shared/widgets/error_banner.dart';
import '../shared/widgets/section_header.dart';
import '../simulation_live/simulation_live_screen.dart';

class SimulationConfigScreen extends StatelessWidget {
  const SimulationConfigScreen({super.key, required this.architecture});

  final ArchitectureGraph architecture;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SimulationConfigViewModel(
        ServiceLocator.instance.simulationRepository,
        architecture,
      ),
      child: const _SimulationConfigView(),
    );
  }
}

class _SimulationConfigView extends StatefulWidget {
  const _SimulationConfigView();

  @override
  State<_SimulationConfigView> createState() => _SimulationConfigViewState();
}

class _SimulationConfigViewState extends State<_SimulationConfigView> {
  final NumberFormat _numberFormat = NumberFormat.decimalPattern();

  Future<void> _launch(SimulationConfigViewModel vm) async {
    final success = await vm.launchExperiment();
    if (success && mounted && vm.simulationId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SimulationLiveScreen(simulationId: vm.simulationId!),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SimulationConfigViewModel>();

    return Scaffold(
      appBar: AppBar(title: const Text('EXPERIMENT')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SectionHeader(
              title: 'Target load',
              subtitle: 'How many concurrent users should the agents simulate?',
            ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: SimulationConfigViewModel.presetUserCounts.map((count) {
                final selected = vm.targetUsers == count;
                return ChoiceChip(
                  label: Text(_numberFormat.format(count)),
                  selected: selected,
                  onSelected: (_) => vm.setTargetUsers(count),
                  selectedColor: AppColors.accent,
                  backgroundColor: AppColors.surfaceRaised,
                  labelStyle: TextStyle(
                    color: selected ? AppColors.background : AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                  side: BorderSide(color: selected ? AppColors.accent : AppColors.border),
                );
              }).toList(),
            ),
            const SizedBox(height: 28),
            const SectionHeader(
              title: 'Failure scenario',
              subtitle: 'Optional — inject a controlled failure alongside the load test.',
            ),
            ...FailureScenarioType.values.map((scenario) {
              final selected = vm.failureScenario == scenario;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => vm.setFailureScenario(scenario),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: selected ? AppColors.accent.withOpacity(0.08) : AppColors.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? AppColors.accent : AppColors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          size: 18,
                          color: selected ? AppColors.accent : AppColors.textMuted,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            scenario.label,
                            style: TextStyle(
                              color: selected ? AppColors.textPrimary : AppColors.textSecondary,
                              fontSize: 13.5,
                              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 28),
            const SectionHeader(title: 'Notes', subtitle: 'Optional context for the agents.'),
            TextField(
              maxLines: 3,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              decoration: const InputDecoration(
                hintText: 'e.g. "We recently migrated the database to a managed instance."',
              ),
              onChanged: vm.setNotes,
            ),
            if (vm.state == ViewState.error && vm.errorMessage != null) ...[
              const SizedBox(height: 16),
              ErrorBanner(message: vm.errorMessage!),
            ],
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: vm.isLoading ? null : () => _launch(vm),
                child: vm.isLoading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.background),
                      )
                    : const Text('RUN EXPERIMENT'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
