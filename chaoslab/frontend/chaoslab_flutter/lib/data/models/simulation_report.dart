import 'enums.dart';
import 'simulation_metrics.dart';

/// Mirrors `AgentStepEvent` in `backend/app/models/schemas.py` — one line
/// item in the live agent-activity feed.
class AgentStepEvent {
  AgentStepEvent({
    required this.agent,
    required this.status,
    required this.headline,
    this.detail,
    required this.sequence,
  });

  final AgentName agent;
  final AgentStepStatus status;
  final String headline;
  final String? detail;
  final int sequence;

  factory AgentStepEvent.fromJson(Map<String, dynamic> json) {
    return AgentStepEvent(
      agent: AgentName.fromWire(json['agent'] as String),
      status: AgentStepStatus.fromWire(json['status'] as String),
      headline: json['headline'] as String,
      detail: json['detail'] as String?,
      sequence: json['sequence'] as int,
    );
  }
}

/// Mirrors `SimulationReport` in `backend/app/models/schemas.py` — the
/// single source of truth polled/streamed for both the live screen and the
/// final report screen.
class SimulationReport {
  SimulationReport({
    required this.simulationId,
    required this.status,
    required this.targetUsers,
    required this.failureScenario,
    this.baselineComponentMetrics = const [],
    this.componentMetrics = const [],
    this.bottlenecks = const [],
    this.criticVerdict,
    this.criticApproved,
    this.remediationPlan = const [],
    this.narrativeSummary,
    this.steps = const [],
    this.error,
  });

  final String simulationId;
  final AgentStepStatus status;
  final int targetUsers;
  final FailureScenarioType failureScenario;

  /// Steady-state (no-failure) metrics, computed alongside the stressed
  /// run so the UI can show "healthy baseline vs. under failure" rather
  /// than only the post-failure numbers in isolation.
  final List<ComponentMetric> baselineComponentMetrics;
  final List<ComponentMetric> componentMetrics;
  final List<BottleneckFinding> bottlenecks;
  final String? criticVerdict;
  final bool? criticApproved;
  final List<RemediationStep> remediationPlan;
  final String? narrativeSummary;
  final List<AgentStepEvent> steps;
  final String? error;

  bool get isTerminal =>
      status == AgentStepStatus.complete || status == AgentStepStatus.failed;

  factory SimulationReport.fromJson(Map<String, dynamic> json) {
    return SimulationReport(
      simulationId: json['simulation_id'] as String,
      status: AgentStepStatus.fromWire(json['status'] as String),
      targetUsers: json['target_users'] as int,
      failureScenario: FailureScenarioType.fromWire(json['failure_scenario'] as String),
      baselineComponentMetrics: (json['baseline_component_metrics'] as List<dynamic>? ?? const [])
          .map((e) => ComponentMetric.fromJson(e as Map<String, dynamic>))
          .toList(),
      componentMetrics: (json['component_metrics'] as List<dynamic>? ?? const [])
          .map((e) => ComponentMetric.fromJson(e as Map<String, dynamic>))
          .toList(),
      bottlenecks: (json['bottlenecks'] as List<dynamic>? ?? const [])
          .map((e) => BottleneckFinding.fromJson(e as Map<String, dynamic>))
          .toList(),
      criticVerdict: json['critic_verdict'] as String?,
      criticApproved: json['critic_approved'] as bool?,
      remediationPlan: (json['remediation_plan'] as List<dynamic>? ?? const [])
          .map((e) => RemediationStep.fromJson(e as Map<String, dynamic>))
          .toList(),
      narrativeSummary: json['narrative_summary'] as String?,
      steps: (json['steps'] as List<dynamic>? ?? const [])
          .map((e) => AgentStepEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
      error: json['error'] as String?,
    );
  }
}
