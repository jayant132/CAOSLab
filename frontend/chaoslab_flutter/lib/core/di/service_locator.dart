import '../../data/datasources/repository_remote_datasource.dart';
import '../../data/datasources/simulation_remote_datasource.dart';
import '../../data/repositories/repository_repository_impl.dart';
import '../../data/repositories/simulation_repository_impl.dart';
import '../../domain/repositories/repository_repository.dart';
import '../../domain/repositories/simulation_repository.dart';
import '../network/dio_client.dart';

/// Deliberately not a code-generated DI framework (get_it, riverpod, etc.)
/// — for a project this size, a handful of `late final` singletons wired
/// once at startup is easier to read and easier to explain in an
/// interview than an annotation-driven container would be.
class ServiceLocator {
  ServiceLocator._internal() {
    final dio = DioClient.instance.dio;

    final repositoryDataSource = RepositoryRemoteDataSource(dio);
    final simulationDataSource = SimulationRemoteDataSource(dio);

    repositoryRepository = RepositoryRepositoryImpl(repositoryDataSource);
    simulationRepository = SimulationRepositoryImpl(simulationDataSource);
  }

  static final ServiceLocator instance = ServiceLocator._internal();

  late final RepositoryRepository repositoryRepository;
  late final SimulationRepository simulationRepository;
}
