import 'package:dio/dio.dart';

bool hasMorePages(int loaded, int pageLength, int pageSize, int? total) =>
    pageLength > 0 && (total == null ? pageLength >= pageSize : loaded < total);

class ApiClient {
  static String? authToken;
  static const _onlineApiBaseUrl = 'http://182.92.129.180:3000/api';

  final Dio _dio = Dio(BaseOptions(
    baseUrl: _apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    sendTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 20),
  ));

  static String get _apiBaseUrl {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (configured.isNotEmpty) return configured;
    return _onlineApiBaseUrl;
  }

  static String mediaUrl(String value) {
    final text = value.trim();
    if (text.isEmpty ||
        text.startsWith('assets/') ||
        text.startsWith('data:') ||
        text.startsWith('blob:')) {
      return text;
    }

    final api = Uri.parse(_apiBaseUrl);
    final origin = api.replace(path: '', query: null, fragment: null);
    final uri = Uri.tryParse(text);
    if (uri == null) return text;
    if (!uri.hasScheme) {
      return origin.resolve(text.startsWith('/') ? text : '/$text').toString();
    }
    if ((uri.scheme == 'http' || uri.scheme == 'https') &&
        _isLoopback(uri.host) &&
        !_isLoopback(api.host)) {
      return uri
          .replace(
            scheme: api.scheme,
            host: api.host,
            port: api.hasPort ? api.port : null,
          )
          .toString();
    }
    return text;
  }

  static bool _isLoopback(String host) {
    return host == 'localhost' || host == '127.0.0.1' || host == '0.0.0.0';
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

  Future<List<dynamic>> requestAllPages(
    String path, {
    Map<String, dynamic>? queryParameters,
    int pageSize = 100,
  }) async {
    final items = <dynamic>[];
    final limit = pageSize.clamp(1, 100);
    // ponytail: preserves the current full-list UI; switch to load-more before lists exceed 10,000 rows.
    for (var page = 1; page <= 100; page += 1) {
      final response = await request(
        path,
        queryParameters: {...?queryParameters, 'page': page, 'limit': limit},
      );
      final pageItems =
          response.data is List ? response.data as List : const [];
      items.addAll(pageItems);
      final total = int.tryParse(response.headers.value('x-total-count') ?? '');
      if (!hasMorePages(items.length, pageItems.length, limit, total)) break;
    }
    return items;
  }
}
