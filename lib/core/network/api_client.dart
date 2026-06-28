import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

class ApiClient {
  static String? authToken;
  static const _developmentHost = '192.168.1.44';

  final Dio _dio = Dio(BaseOptions(
    baseUrl: _apiBaseUrl,
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 3),
  ));

  static String get _apiBaseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) return configured;

    final host = kIsWeb
        ? (Uri.base.host.isEmpty ? 'localhost' : Uri.base.host)
        : _developmentHost;
    return 'http://$host:3000/api';
  }

  // 统一请求处理，方便以后添加 Token 验证
  Future<Response> request(String path,
      {String method = 'GET',
      dynamic data,
      Map<String, dynamic>? queryParameters}) async {
    try {
      return await _dio.request(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(
          method: method,
          headers:
              authToken == null ? null : {'Authorization': 'Bearer $authToken'},
        ),
      );
    } catch (e) {
      rethrow;
    }
  }
}
