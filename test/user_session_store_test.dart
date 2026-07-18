import 'package:flutter_test/flutter_test.dart';
import 'package:hot_hair_app/core/network/api_client.dart';
import 'package:hot_hair_app/features/auth/data/user_session_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('missing token requires login instead of creating a demo session', () async {
    SharedPreferences.setMockInitialValues({});
    ApiClient.authToken = 'stale-token';

    expect(await UserSessionStore.restore(), isNull);
    expect(UserSessionStore.currentSession, isNull);
    expect(ApiClient.authToken, isNull);
  });
}
