import '../../core/network/sse_client.dart';
import '../../data/models/architecture_graph.dart';
import '../../data/models/enums.dart';
import '../../data/models/simulation_report.dart';

abstract class SimulationRepository {
  /// Kicks off the agent pipeline on the backend, returns the new
  /// simulation id immediately (the run itself continues async).
  Future<String> executeSimulation({
    required ArchitectureGraph architecture,
    required int targetUsers,
    required FailureScenarioType failureScenario,
    String? notes,
  });

  /// Raw SSE event stream for a running simulation — the ViewModel decides
  /// how to interpret `agent_step` vs `final_report` events.
  Stream<SseEvent> streamProgress(String simulationId);

  /// One-shot poll, used as a fallback if the SSE connection drops.
  Future<SimulationReport> getReport(String simulationId);
}
