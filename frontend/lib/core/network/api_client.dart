import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'exceptions.dart';

const _baseUrl = 'http://localhost:8000/api';
const _storage = FlutterSecureStorage();

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {'Content-Type': 'application/json'},
  ));

  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final token = await _storage.read(key: 'access_token');
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
    onError: (error, handler) {
      if (error.response != null) {
        final statusCode = error.response!.statusCode ?? 500;
        final data = error.response!.data;
        final message = data is Map ? (data['detail'] ?? 'Unknown error') : 'Server error';
        handler.reject(DioException(
          requestOptions: error.requestOptions,
          error: ApiException(statusCode: statusCode, message: message.toString()),
          type: DioExceptionType.badResponse,
          response: error.response,
        ));
      } else {
        handler.reject(DioException(
          requestOptions: error.requestOptions,
          error: NetworkException('Connection failed'),
          type: DioExceptionType.connectionError,
        ));
      }
    },
  ));

  return dio;
});

final storageProvider = Provider<FlutterSecureStorage>((ref) => _storage);
