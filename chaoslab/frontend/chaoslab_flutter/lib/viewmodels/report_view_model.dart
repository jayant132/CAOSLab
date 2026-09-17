import 'package:flutter/foundation.dart';

import '../core/network/dio_client.dart';
import '../core/utils/view_state.dart';
import '../data/models/simulation_metrics.dart';
import '../data/models/simulation_report.dart';
import '../domain/repositories/simulation_repository.dart';

/// Backs the final report screen. Usually constructed with the report the
/// live screen already streamed to completion (no extra network call),
/// but also supports fetching by id directly — e.g. a "history" list or a
/// deep link straight into a past report.
class ReportViewModel extends ChangeNotifier {
  ReportViewModel(this._repository, {SimulationReport? initialReport, String? simulationId})
      : report = initialReport,
        _simulationId = simulationId ?? initialReport?.simulationId {
    if (report == null && _simulationId != null) {
      _fetch();
    } else if (report != null) {
      state = ViewState.success;
    }
  }

  final SimulationRepository _repository;
  final String? _simulationId;

  ViewState state = ViewState.idle;
  String? errorMessage;
  SimulationReport? report;

  BottleneckFinding? get topBottleneck {
    if (report == null || report!.bottlenecks.isEmpty) return null;
    final sorted = [...report!.bottlenecks]
      ..sort((a, b) => b.riskScorePct.compareTo(a.riskScorePct));
    return sorted.first;
  }

  ComponentMetric? metricFor(String serviceName) {
    if (report == null) return null;
    for (final m in report!.componentMetrics) {
      if (m.serviceName == serviceName) return m;
    }
    return null;
  }

  Future<void> _fetch() async {
    state = ViewState.loading;
    notifyListeners();
    try {
      report = await _repository.getReport(_simulationId!);
      state = ViewState.success;
    } catch (error) {
      errorMessage = error is ApiException ? error.message : 'Could not load this report.';
      state = ViewState.error;
    }
    notifyListeners();
  }

  Future<void> refresh() => _fetch();
}
