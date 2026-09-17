import '../../domain/repositories/repository_repository.dart';
import '../datasources/repository_remote_datasource.dart';
import '../models/repository_inspect_result.dart';

class RepositoryRepositoryImpl implements RepositoryRepository {
  RepositoryRepositoryImpl(this._dataSource);

  final RepositoryRemoteDataSource _dataSource;

  @override
  Future<RepositoryInspectResult> inspectRepository(String repoUrl) {
    return _dataSource.inspectRepository(repoUrl);
  }
}
