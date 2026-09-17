import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/network/sse_client.dart';
import '../core/utils/view_state.dart';
import '../data/models/simulation_report.dart';
import '../domain/repositories/simulation_repository.dart';

/// Backs the live "agent activity feed" screen — this is the product's
/// visual differentiator, so this ViewModel's whole job is turning the
/// raw SSE stream into something the view can render incrementally as
/// each agent hands off to the next one.
///
/// The backend emits two event types on `/api/v1/simulation/stream/{id}`:
///   - `event: agent_step`  -> one `AgentStepEvent` (append to the feed)
///   - `event: final_report` -> the terminal `SimulationReport`
///
/// If the SSE connection drops before a terminal event arrives, this
/// falls back to polling `getReport` once so the screen doesn't get stuck.
class SimulationLiveViewModel extends ChangeNotifier {
  SimulationLiveViewModel(this._repository, this.simulationId) {
    _subscribe();
  }

  final SimulationRepository _repository;
  final String simulationId;

  ViewState state = ViewState.loading;
  String? errorMessage;

  final List<AgentStepEvent> steps = [];
  SimulationReport? finalReport;

  StreamSubscription<SseEvent>? _subscription;

  bool get isComplete => finalReport?.isTerminal ?? false;

  void _subscribe() {
    _subscription = _repository.streamProgress(simulationId).listen(
      _handleEvent,
      onError: _handleStreamError,
      onDone: _handleStreamDone,
    );
  }

  void _handleEvent(SseEvent event) {
    switch (event.event) {
      case 'agent_step':
        final json = jsonDecode(event.data) as Map<String, dynamic>;
        steps.add(AgentStepEvent.fromJson(json));
        notifyListeners();
        break;
      case 'final_report':
        final json = jsonDecode(event.data) as Map<String, dynamic>;
        finalReport = SimulationReport.fromJson(json);
        state = ViewState.success;
        notifyListeners();
        break;
      default:
        // Unknown event types are ignored rather than crashing the feed —
        // forward-compatible with the backend adding new event kinds.
        break;
    }
  }

  Future<void> _handleStreamError(Object error) async {
    // The stream itself failed (e.g. connection dropped mid-run). Fall
    // back to a single poll of the report endpoint before giving up.
    await _fallbackPoll();
  }

  Future<void> _handleStreamDone() async {
    if (finalReport == null) {
      await _fallbackPoll();
    }
  }

  Future<void> _fallbackPoll() async {
    try {
      final report = await _repository.getReport(simulationId);
      finalReport = report;
      state = report.isTerminal ? ViewState.success : ViewState.error;
      if (!report.isTerminal) {
        errorMessage = 'Lost connection to the simulation before it finished.';
      }
    } catch (_) {
      state = ViewState.error;
      errorMessage = 'Lost connection to the simulation and could not recover.';
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
