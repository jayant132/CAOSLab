/// Mirrors `FailureScenarioType` in `backend/app/models/schemas.py`.
enum FailureScenarioType {
  none,
  databaseLatencySpike,
  cacheOutage,
  dependencyTimeout,
  trafficSurge,
  instanceLoss;

  /// The wire value the backend expects/returns (snake_case).
  String get wireValue {
    switch (this) {
      case FailureScenarioType.none:
        return 'none';
      case FailureScenarioType.databaseLatencySpike:
        return 'database_latency_spike';
      case FailureScenarioType.cacheOutage:
        return 'cache_outage';
      case FailureScenarioType.dependencyTimeout:
        return 'dependency_timeout';
      case FailureScenarioType.trafficSurge:
        return 'traffic_surge';
      case FailureScenarioType.instanceLoss:
        return 'instance_loss';
    }
  }

  /// Human label shown in the picker UI.
  String get label {
    switch (this) {
      case FailureScenarioType.none:
        return 'No failure — steady state';
      case FailureScenarioType.databaseLatencySpike:
        return 'Database latency spike (+300%)';
      case FailureScenarioType.cacheOutage:
        return 'Cache layer total outage';
      case FailureScenarioType.dependencyTimeout:
        return 'Upstream dependency timeout';
      case FailureScenarioType.trafficSurge:
        return 'Sudden 3x traffic surge';
      case FailureScenarioType.instanceLoss:
        return 'Loss of API/gateway instances';
    }
  }

  static FailureScenarioType fromWire(String value) {
    return FailureScenarioType.values.firstWhere(
      (e) => e.wireValue == value,
      orElse: () => FailureScenarioType.none,
    );
  }
}

/// Mirrors `AgentName` in `backend/app/models/schemas.py`. Order here also
/// drives the fixed vertical order of the live agent-activity feed.
///
/// Reduced from an earlier 7-value enum: `trafficAgent` / `capacityAgent` /
/// `failureAgent` were three deterministic-only steps now run as one
/// `simulationAgent` pass, and `criticAgent` (a deterministic evidence
/// check, not an LLM call) now runs inline inside `investigatorAgent` as a
/// bounded self-verification step. See backend/app/agents/graph.py.
enum AgentName {
  architectureAgent,
  simulationAgent,
  investigatorAgent,
  remediationAgent;

  String get wireValue {
    switch (this) {
      case AgentName.architectureAgent:
        return 'architecture_agent';
      case AgentName.simulationAgent:
        return 'simulation_agent';
      case AgentName.investigatorAgent:
        return 'investigator_agent';
      case AgentName.remediationAgent:
        return 'remediation_agent';
    }
  }

  String get label {
    switch (this) {
      case AgentName.architectureAgent:
        return 'Architecture Agent';
      case AgentName.simulationAgent:
        return 'Simulation Agent';
      case AgentName.investigatorAgent:
        return 'Investigator Agent';
      case AgentName.remediationAgent:
        return 'Remediation Agent';
    }
  }

  /// One-line description of what this stage does — used for the pipeline
  /// legend / empty state on the live agent screen.
  String get subtitle {
    switch (this) {
      case AgentName.architectureAgent:
        return 'Reads the parsed topology';
      case AgentName.simulationAgent:
        return 'Deterministic capacity + failure model';
      case AgentName.investigatorAgent:
        return 'Ranks bottlenecks, self-verifies against evidence';
      case AgentName.remediationAgent:
        return 'Produces recommendations + summary';
    }
  }

  static AgentName fromWire(String value) {
    return AgentName.values.firstWhere(
      (e) => e.wireValue == value,
      orElse: () => AgentName.architectureAgent,
    );
  }
}

/// Mirrors `AgentStepStatus` in `backend/app/models/schemas.py`.
enum AgentStepStatus {
  pending,
  running,
  complete,
  failed;

  static AgentStepStatus fromWire(String value) {
    return AgentStepStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => AgentStepStatus.pending,
    );
  }
}
