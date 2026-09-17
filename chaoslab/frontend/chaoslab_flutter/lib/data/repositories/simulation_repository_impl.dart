import '../../core/network/sse_client.dart';
import '../../domain/repositories/simulation_repository.dart';
import '../datasources/simulation_remote_datasource.dart';
import '../models/architecture_graph.dart';
import '../models/enums.dart';
import '../models/simulation_report.dart';

class SimulationRepositoryImpl implements SimulationRepository {
  SimulationRepositoryImpl(this._dataSource);

  final SimulationRemoteDataSource _dataSource;

  @override
  Future<String> executeSimulation({
    required ArchitectureGraph architecture,
    required int targetUsers,
    required FailureScenarioType failureScenario,
    String? notes,
  }) {
    return _dataSource.executeSimulation(
      architecture: architecture,
      targetUsers: targetUsers,
      failureScenario: failureScenario,
      notes: notes,
    );
  }

  @override
  Stream<SseEvent> streamProgress(String simulationId) {
    return _dataSource.streamProgress(simulationId);
  }

  @override
  Future<SimulationReport> getReport(String simulationId) {
    return _dataSource.getReport(simulationId);
  }
}
