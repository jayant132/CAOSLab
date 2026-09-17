import 'package:dio/dio.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/dio_client.dart';
import '../../core/network/sse_client.dart';
import '../models/architecture_graph.dart';
import '../models/enums.dart';
import '../models/simulation_report.dart';

class SimulationRemoteDataSource {
  SimulationRemoteDataSource(this._dio) : _sse = SseClient(_dio);

  final Dio _dio;
  final SseClient _sse;

  Future<String> executeSimulation({
    required ArchitectureGraph architecture,
    required int targetUsers,
    required FailureScenarioType failureScenario,
    String? notes,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiConstants.simulationExecute,
        data: {
          'architecture': architecture.toJson(),
          'target_users': targetUsers,
          'failure_scenario': failureScenario.wireValue,
          'notes': notes,
        },
      );
      return response.data!['simulation_id'] as String;
    } catch (error) {
      throw DioClient.instance.toApiException(error);
    }
  }

  Stream<SseEvent> streamProgress(String simulationId) {
    return _sse.connect(ApiConstants.simulationStream(simulationId));
  }

  Future<SimulationReport> getReport(String simulationId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiConstants.simulationReport(simulationId),
      );
      return SimulationReport.fromJson(response.data!);
    } catch (error) {
      throw DioClient.instance.toApiException(error);
    }
  }
}
