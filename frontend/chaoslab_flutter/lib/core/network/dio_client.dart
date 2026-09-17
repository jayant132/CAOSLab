import 'package:dio/dio.dart';

import '../constants/api_constants.dart';

/// Thin exception wrapper so ViewModels never need to know about Dio's
/// exception types directly — they only ever catch [ApiException].
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

/// Single shared Dio instance for the whole app. Kept as a plain singleton
/// (not a DI container) deliberately — this is a small app and the
/// indirection isn't worth it, but every data source only ever depends on
/// this class, so swapping it out later is a one-file change.
class DioClient {
  DioClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        headers: {'Content-Type': 'application/json'},
      ),
    );
  }

  static final DioClient instance = DioClient._internal();

  late final Dio _dio;

  Dio get dio => _dio;

  ApiException toApiException(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      String message = error.message ?? 'Network error';
      if (data is Map && data['detail'] != null) {
        message = data['detail'].toString();
      }
      return ApiException(message, statusCode: error.response?.statusCode);
    }
    return ApiException(error.toString());
  }
}
