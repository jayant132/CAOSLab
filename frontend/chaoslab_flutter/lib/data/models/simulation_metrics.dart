/// Mirrors `ComponentMetric` in `backend/app/models/schemas.py`.
class ComponentMetric {
  ComponentMetric({
    required this.serviceName,
    required this.role,
    required this.cpuUtilizationPct,
    required this.memoryUtilizationPct,
    required this.p95LatencyMs,
    required this.errorRatePct,
    required this.instancesRequired,
    required this.riskScorePct,
  });

  final String serviceName;
  final String role;
  final double cpuUtilizationPct;
  final double memoryUtilizationPct;
  final double p95LatencyMs;
  final double errorRatePct;
  final int instancesRequired;
  final double riskScorePct;

  factory ComponentMetric.fromJson(Map<String, dynamic> json) {
    return ComponentMetric(
      serviceName: json['service_name'] as String,
      role: json['role'] as String,
      cpuUtilizationPct: (json['cpu_utilization_pct'] as num).toDouble(),
      memoryUtilizationPct: (json['memory_utilization_pct'] as num).toDouble(),
      p95LatencyMs: (json['p95_latency_ms'] as num).toDouble(),
      errorRatePct: (json['error_rate_pct'] as num).toDouble(),
      instancesRequired: json['instances_required'] as int,
      riskScorePct: (json['risk_score_pct'] as num).toDouble(),
    );
  }
}

/// Mirrors `BottleneckFinding` in `backend/app/models/schemas.py`.
class BottleneckFinding {
  BottleneckFinding({
    required this.serviceName,
    required this.riskScorePct,
    required this.reasoning,
  });

  final String serviceName;
  final double riskScorePct;
  final String reasoning;

  factory BottleneckFinding.fromJson(Map<String, dynamic> json) {
    return BottleneckFinding(
      serviceName: json['service_name'] as String,
      riskScorePct: (json['risk_score_pct'] as num).toDouble(),
      reasoning: json['reasoning'] as String? ?? '',
    );
  }
}

/// Mirrors `RemediationStep` in `backend/app/models/schemas.py`.
class RemediationStep {
  RemediationStep({
    required this.title,
    required this.description,
    required this.expectedImpact,
  });

  final String title;
  final String description;
  final String expectedImpact;

  factory RemediationStep.fromJson(Map<String, dynamic> json) {
    return RemediationStep(
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      expectedImpact: json['expected_impact'] as String? ?? '',
    );
  }
}
