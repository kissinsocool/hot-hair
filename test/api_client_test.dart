import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../lib/core/network/api_client.dart';

void main() {
  test('pagination stops at the reported total', () {
    expect(hasMorePages(100, 100, 100, 250), isTrue);
    expect(hasMorePages(250, 50, 100, 250), isFalse);
    expect(hasMorePages(100, 100, 100, null), isTrue);
    expect(hasMorePages(50, 50, 100, null), isFalse);
  });

  test('rate limit errors use a friendly message', () {
    final request = RequestOptions(path: '/salons');
    final error = DioException(
      requestOptions: request,
      response: Response(requestOptions: request, statusCode: 429),
    );

    expect(
      ApiClient.errorMessage(error, fallback: '加载失败'),
      '操作频繁，请稍后再试',
    );
  });
}
