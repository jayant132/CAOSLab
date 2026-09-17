/// Mirrors `ServiceNode` in `backend/app/models/schemas.py`.
class ServiceNode {
  ServiceNode({
    required this.name,
    this.image,
    this.buildContext,
    this.ports = const [],
    this.dependsOn = const [],
    this.environmentKeys = const [],
    this.inferredRole = 'unknown',
    this.cpuLimit,
    this.memoryLimitMb,
    this.replicas = 1,
  });

  final String name;
  final String? image;
  final String? buildContext;
  final List<String> ports;
  final List<String> dependsOn;
  final List<String> environmentKeys;
  final String inferredRole;
  final double? cpuLimit;
  final int? memoryLimitMb;
  final int replicas;

  factory ServiceNode.fromJson(Map<String, dynamic> json) {
    return ServiceNode(
      name: json['name'] as String,
      image: json['image'] as String?,
      buildContext: json['build_context'] as String?,
      ports: (json['ports'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      dependsOn: (json['depends_on'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      environmentKeys: (json['environment_keys'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      inferredRole: json['inferred_role'] as String? ?? 'unknown',
      cpuLimit: (json['cpu_limit'] as num?)?.toDouble(),
      memoryLimitMb: json['memory_limit_mb'] as int?,
      replicas: json['replicas'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'image': image,
        'build_context': buildContext,
        'ports': ports,
        'depends_on': dependsOn,
        'environment_keys': environmentKeys,
        'inferred_role': inferredRole,
        'cpu_limit': cpuLimit,
        'memory_limit_mb': memoryLimitMb,
        'replicas': replicas,
      };

  ServiceNode copyWith({int? replicas}) {
    return ServiceNode(
      name: name,
      image: image,
      buildContext: buildContext,
      ports: ports,
      dependsOn: dependsOn,
      environmentKeys: environmentKeys,
      inferredRole: inferredRole,
      cpuLimit: cpuLimit,
      memoryLimitMb: memoryLimitMb,
      replicas: replicas ?? this.replicas,
    );
  }
}

/// Mirrors `ArchitectureGraph` in `backend/app/models/schemas.py`.
class ArchitectureGraph {
  ArchitectureGraph({
    required this.repoFullName,
    required this.defaultBranch,
    required this.services,
    this.edges = const [],
    this.composeFilePath,
    this.usedFallback = false,
    this.fallbackReason,
  });

  final String repoFullName;
  final String defaultBranch;
  final List<ServiceNode> services;
  final List<List<String>> edges;
  final String? composeFilePath;
  final bool usedFallback;
  final String? fallbackReason;

  factory ArchitectureGraph.fromJson(Map<String, dynamic> json) {
    return ArchitectureGraph(
      repoFullName: json['repo_full_name'] as String,
      defaultBranch: json['default_branch'] as String,
      services: (json['services'] as List<dynamic>? ?? const [])
          .map((e) => ServiceNode.fromJson(e as Map<String, dynamic>))
          .toList(),
      edges: (json['edges'] as List<dynamic>? ?? const [])
          .map((e) => (e as List<dynamic>).map((x) => x.toString()).toList())
          .toList(),
      composeFilePath: json['compose_file_path'] as String?,
      usedFallback: json['used_fallback'] as bool? ?? false,
      fallbackReason: json['fallback_reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'repo_full_name': repoFullName,
        'default_branch': defaultBranch,
        'services': services.map((s) => s.toJson()).toList(),
        'edges': edges,
        'compose_file_path': composeFilePath,
        'used_fallback': usedFallback,
        'fallback_reason': fallbackReason,
      };

  ArchitectureGraph copyWithServices(List<ServiceNode> updatedServices) {
    return ArchitectureGraph(
      repoFullName: repoFullName,
      defaultBranch: defaultBranch,
      services: updatedServices,
      edges: edges,
      composeFilePath: composeFilePath,
      usedFallback: usedFallback,
      fallbackReason: fallbackReason,
    );
  }
}
