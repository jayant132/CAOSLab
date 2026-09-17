import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/di/service_locator.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/view_state.dart';
import '../../data/models/simulation_report.dart';
import '../../viewmodels/report_view_model.dart';
import '../repo_input/repo_input_screen.dart';
import '../shared/widgets/error_banner.dart';
import '../shared/widgets/section_header.dart';
import 'widgets/bottleneck_card.dart';
import 'widgets/component_metric_card.dart';
import 'widgets/remediation_card.dart';

/// The payoff screen: what broke, why the Investigator's finding held up
/// under self-verification, and what to change — framed with "estimated"
/// language throughout rather than pretending the model predicts the future.
class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key, this.report, this.simulationId})
      : assert(report != null || simulationId != null);

  final SimulationReport? report;
  final String? simulationId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ReportViewModel(
        ServiceLocator.instance.simulationRepository,
        initialReport: report,
        simulationId: simulationId,
      ),
      child: const _ReportView(),
    );
  }
}

class _ReportView extends StatelessWidget {
  const _ReportView();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReportViewModel>();
    final numberFormat = NumberFormat.decimalPattern();

    return Scaffold(
      appBar: AppBar(
        title: const Text('FINDINGS'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'New experiment',
            onPressed: () => Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const RepoInputScreen()),
              (route) => false,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Builder(
          builder: (context) {
            if (vm.state == ViewState.loading) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              );
            }

            if (vm.state == ViewState.error) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: ErrorBanner(message: vm.errorMessage ?? 'Could not load this report.'),
              );
            }

            final r = vm.report;
            if (r == null) {
              return const Center(
                child: Text('No report available.', style: TextStyle(color: AppColors.textMuted)),
              );
            }

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                if (r.bottlenecks.isNotEmpty) ...[
                  _OverallRiskBanner(report: r),
                  const SizedBox(height: 16),
                ],
                _SummaryHeader(report: r, numberFormat: numberFormat),
                const SizedBox(height: 24),
                if (r.narrativeSummary != null) ...[
                  Card(
                    color: AppColors.surfaceRaised,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        r.narrativeSummary!,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 14,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                if (r.bottlenecks.isNotEmpty) ...[
                  const SectionHeader(
                    title: 'Bottlenecks',
                    subtitle: 'Ranked by estimated risk under this scenario.',
                  ),
                  ...(() {
                    final sorted = [...r.bottlenecks]
                      ..sort((a, b) => b.riskScorePct.compareTo(a.riskScorePct));
                    return sorted.asMap().entries.map(
                      (entry) => BottleneckCard(finding: entry.value, isTop: entry.key == 0),
                    );
                  })(),
                  const SizedBox(height: 12),
                ],
                if (r.criticVerdict != null && r.criticVerdict!.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          r.criticApproved == false ? Icons.rule : Icons.verified_outlined,
                          size: 16,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Investigator self-check (evidence-verified): ${r.criticVerdict}',
                            style: const TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                if (r.componentMetrics.isNotEmpty) ...[
                  const SectionHeader(
                    title: 'Component metrics',
                    subtitle: 'Estimated utilization, latency, and error rate per service.',
                  ),
                  ...r.componentMetrics.map((m) => ComponentMetricCard(metric: m)),
                  const SizedBox(height: 12),
                ],
                if (r.remediationPlan.isNotEmpty) ...[
                  const SectionHeader(
                    title: 'Remediation plan',
                    subtitle: 'What to change, and the estimated effect of changing it.',
                  ),
                  ...r.remediationPlan.asMap().entries.map(
                    (entry) => RemediationCard(step: entry.value, index: entry.key + 1),
                  ),
                ],
                const SizedBox(height: 12),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SummaryHeader extends StatelessWidget {
  const _SummaryHeader({required this.report, required this.numberFormat});

  final SimulationReport report;
  final NumberFormat numberFormat;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            label: 'Target load',
            value: '${numberFormat.format(report.targetUsers)} users',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatTile(
            label: 'Scenario',
            value: report.failureScenario.label,
          ),
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 10.5, fontWeight: FontWeight.w700, letterSpacing: 0.6),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// Top-of-report banner: overall risk level + primary bottleneck, so the
/// single most important conclusion is legible in the first second — the
/// "HIGH RISK / primary bottleneck: X" reading a static screenshot needs.
/// Risk level and bottleneck name both come straight from
/// `report.bottlenecks`, computed by the deterministic capacity model —
/// nothing here is invented for display purposes.
class _OverallRiskBanner extends StatelessWidget {
  const _OverallRiskBanner({required this.report});

  final SimulationReport report;

  @override
  Widget build(BuildContext context) {
    final sorted = [...report.bottlenecks]..sort((a, b) => b.riskScorePct.compareTo(a.riskScorePct));
    final top = sorted.first;
    final riskColor = AppColors.riskColor(top.riskScorePct);
    final riskLabel = top.riskScorePct >= 70
        ? 'HIGH RISK'
        : top.riskScorePct >= 40
            ? 'MEDIUM RISK'
            : 'LOW RISK';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: riskColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppSpacing.radiusLg),
        border: Border.all(color: riskColor.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(color: riskColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  riskLabel,
                  style: TextStyle(color: riskColor, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 1.0),
                ),
                const SizedBox(height: 6),
                Text(
                  'Primary bottleneck: ${top.serviceName}',
                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  'Estimated risk score: ${top.riskScorePct.toStringAsFixed(0)}% (deterministic capacity model)',
                  style: AppFonts.code,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
