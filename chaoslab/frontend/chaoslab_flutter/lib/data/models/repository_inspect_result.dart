import 'architecture_graph.dart';

/// Mirrors `RepositoryInspectResponse` in `backend/app/models/schemas.py`.
class RepositoryInspectResult {
  RepositoryInspectResult({required this.architecture, this.warnings = const []});

  final ArchitectureGraph architecture;
  final List<String> warnings;

  factory RepositoryInspectResult.fromJson(Map<String, dynamic> json) {
    return RepositoryInspectResult(
      architecture: ArchitectureGraph.fromJson(json['architecture'] as Map<String, dynamic>),
      warnings: (json['warnings'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}
