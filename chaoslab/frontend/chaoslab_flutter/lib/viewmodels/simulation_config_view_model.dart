import 'package:flutter/foundation.dart';

import '../core/network/dio_client.dart';
import '../core/utils/view_state.dart';
import '../data/models/architecture_graph.dart';
import '../data/models/enums.dart';
import '../domain/repositories/simulation_repository.dart';

/// Backs the "choose target load + failure scenario, then launch" screen.
/// On success it exposes the new `simulationId` for the router to hand
/// off to the live agent-activity screen.
class SimulationConfigViewModel extends ChangeNotifier {
  SimulationConfigViewModel(this._repository, this.architecture);

  final SimulationRepository _repository;
  final ArchitectureGraph architecture;

  int targetUsers = 100000;
  FailureScenarioType failureScenario = FailureScenarioType.none;
  String notes = '';

  ViewState state = ViewState.idle;
  String? errorMessage;
  String? simulationId;

  bool get isLoading => state == ViewState.loading;

  static const List<int> presetUserCounts = [
    1000,
    10000,
    100000,
    1000000,
    10000000,
  ];

  void setTargetUsers(int users) {
    targetUsers = users;
    notifyListeners();
  }

  void setFailureScenario(FailureScenarioType scenario) {
    failureScenario = scenario;
    notifyListeners();
  }

  void setNotes(String value) {
    notes = value;
  }

  Future<bool> launchExperiment() async {
    state = ViewState.loading;
    errorMessage = null;
    notifyListeners();

    try {
      simulationId = await _repository.executeSimulation(
        architecture: architecture,
        targetUsers: targetUsers,
        failureScenario: failureScenario,
        notes: notes.trim().isEmpty ? null : notes.trim(),
      );
      state = ViewState.success;
      notifyListeners();
      return true;
    } catch (error) {
      errorMessage = error is ApiException ? error.message : 'Something went wrong.';
      state = ViewState.error;
      notifyListeners();
      return false;
    }
  }
}
