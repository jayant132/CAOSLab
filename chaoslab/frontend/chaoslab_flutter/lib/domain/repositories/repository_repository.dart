import '../../data/models/repository_inspect_result.dart';

/// Domain-facing contract for turning a GitHub URL into an
/// [ArchitectureGraph]. ViewModels depend on this abstraction, never on
/// Dio or the concrete data source directly — that indirection is what
/// makes the MVVM boundary real rather than cosmetic.
abstract class RepositoryRepository {
  Future<RepositoryInspectResult> inspectRepository(String repoUrl);
}
