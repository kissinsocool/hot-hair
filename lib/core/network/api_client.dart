import 'package:dio/dio.dart';

class ApiClient {
  static String? authToken;

  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'http://localhost:3000/api', // 替换为实际后端地址
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 3),
  ));

  // 统一请求处理，方便以后添加 Token 验证
  Future<Response> request(String path,
      {String method = 'GET', dynamic data}) async {
    try {
      return await _dio.request(
        path,
        data: data,
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
