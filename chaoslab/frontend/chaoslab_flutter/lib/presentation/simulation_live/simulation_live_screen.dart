import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/di/service_locator.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/view_state.dart';
import '../../viewmodels/simulation_live_view_model.dart';
import '../report/report_screen.dart';
import '../shared/widgets/error_banner.dart';
import 'widgets/agent_activity_row.dart';
import 'widgets/agent_pipeline_legend.dart';

class SimulationLiveScreen extends StatelessWidget {
  const SimulationLiveScreen({super.key, required this.simulationId});

  final String simulationId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SimulationLiveViewModel(
        ServiceLocator.instance.simulationRepository,
        simulationId,
      ),
      child: const _SimulationLiveView(),
    );
  }
}

class _SimulationLiveView extends StatefulWidget {
  const _SimulationLiveView();

  @override
  State<_SimulationLiveView> createState() => _SimulationLiveViewState();
}

class _SimulationLiveViewState extends State<_SimulationLiveView> {
  final ScrollController _scrollController = ScrollController();
  bool _navigated = false;

  void _maybeNavigateToReport(SimulationLiveViewModel vm) {
    if (_navigated || !vm.isComplete || vm.finalReport == null) return;
    _navigated = true;
    Future.microtask(() {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => ReportScreen(report: vm.finalReport!)),
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SimulationLiveViewModel>();

    // Auto-scroll to the newest event as it streams in.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });

    _maybeNavigateToReport(vm);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AGENTS AT WORK'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: vm.isComplete ? AppColors.statusHealthy : AppColors.accent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    vm.isComplete ? 'Pipeline complete' : 'Running multi-agent pipeline…',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            if (vm.state == ViewState.error && vm.errorMessage != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ErrorBanner(message: vm.errorMessage!),
              ),
            AgentPipelineLegend(
              reachedAgents: vm.steps.map((s) => s.agent).toSet(),
            ),
            Expanded(
              child: vm.steps.isEmpty
                  ? const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      itemCount: vm.steps.length,
                      itemBuilder: (context, index) {
                        final step = vm.steps[index];
                        return AgentActivityRow(
                          step: step,
                          isLatest: index == vm.steps.length - 1 && !vm.isComplete,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
