import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import 'user_auth_repository.dart';

class UserSessionStore {
  UserSessionStore._();

  static const _tokenKey = 'client_auth_token';
  static const _userIdKey = 'client_user_id';
  static const _accountKey = 'client_user_account';
  static const _displayNameKey = 'client_user_display_name';
  static const _genderKey = 'client_user_gender';
  static const _avatarUrlKey = 'client_user_avatar_url';
  static const _phoneKey = 'client_user_phone';

  static ClientAuthSession? currentSession;

  static Future<ClientAuthSession?> restore() async {
    final preferences = await SharedPreferences.getInstance();
    final token = preferences.getString(_tokenKey);
    if (token == null || token.isEmpty) {
      currentSession = const ClientAuthSession(
        token: '',
        user: ClientUser(
          id: 'demo',
          account: 'demo',
          displayName: 'Demo 用户',
          phone: 'demo',
        ),
      );
      return currentSession;
    }

    final session = ClientAuthSession(
      token: token,
      user: ClientUser(
        id: preferences.getString(_userIdKey) ?? '',
        account: preferences.getString(_accountKey) ?? '',
        displayName: preferences.getString(_displayNameKey) ?? '',
        gender: preferences.getString(_genderKey) ?? '保密',
        avatarUrl: preferences.getString(_avatarUrlKey) ?? '',
        phone: preferences.getString(_phoneKey) ??
            preferences.getString(_accountKey) ??
            '',
      ),
    );
    currentSession = session;
    ApiClient.authToken = token;
    return session;
  }

  static Future<void> save(ClientAuthSession session) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_tokenKey, session.token);
    await preferences.setString(_userIdKey, session.user.id);
    await preferences.setString(_accountKey, session.user.account);
    await preferences.setString(_displayNameKey, session.user.displayName);
    await preferences.setString(_genderKey, session.user.gender);
    await preferences.setString(_avatarUrlKey, session.user.avatarUrl);
    await preferences.setString(_phoneKey, session.user.phone);
    currentSession = session;
    ApiClient.authToken = session.token;
  }

  static Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_tokenKey);
    await preferences.remove(_userIdKey);
    await preferences.remove(_accountKey);
    await preferences.remove(_displayNameKey);
    await preferences.remove(_genderKey);
    await preferences.remove(_avatarUrlKey);
    await preferences.remove(_phoneKey);
    currentSession = null;
    ApiClient.authToken = null;
  }
}
