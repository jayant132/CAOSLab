import 'package:dio/dio.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import '../models/repository_inspect_result.dart';

class RepositoryRemoteDataSource {
  RepositoryRemoteDataSource(this._dio);

  final Dio _dio;

  Future<RepositoryInspectResult> inspectRepository(String repoUrl) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiConstants.repositoryInspect,
        data: {'repo_url': repoUrl},
      );
      return RepositoryInspectResult.fromJson(response.data!);
    } catch (error) {
      throw DioClient.instance.toApiException(error);
    }
  }
}
