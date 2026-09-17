import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Endpoint paths mirror `backend/app/routers/*.py` field-for-field.
/// Keeping them centralized here means a backend route rename only ever
/// touches this one file on the Flutter side.
class ApiConstants {
  ApiConstants._();

  static String get baseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'http://127.0.0.1:8000';

  static const String systemPulse = '/api/v1/system/pulse';
  static const String repositoryInspect = '/api/v1/repository/inspect';
  static const String simulationExecute = '/api/v1/simulation/execute';
  static String simulationStream(String simulationId) =>
      '/api/v1/simulation/stream/$simulationId';
  static String simulationReport(String simulationId) =>
      '/api/v1/simulation/report/$simulationId';

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 20);
}
