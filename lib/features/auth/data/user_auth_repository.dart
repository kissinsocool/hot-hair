import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';

class ClientUser {
  final String id;
  final String account;
  final String displayName;
  final String gender;
  final String avatarUrl;
  final String phone;

  const ClientUser({
    required this.id,
    required this.account,
    required this.displayName,
    this.gender = '保密',
    this.avatarUrl = '',
    this.phone = '',
  });

  factory ClientUser.fromJson(Map<String, dynamic> json) {
    final account = json['account']?.toString() ?? '';
    return ClientUser(
      id: json['id']?.toString() ?? '',
      account: account,
      displayName: json['displayName']?.toString() ?? '',
      gender: json['gender']?.toString() ?? '保密',
      avatarUrl: json['avatarUrl']?.toString() ?? '',
      phone: json['phone']?.toString() ?? account,
    );
  }

  Map<String, String> toJson() => {
        'id': id,
        'account': account,
        'displayName': displayName,
        'gender': gender,
        'avatarUrl': avatarUrl,
        'phone': phone,
      };
}

class ClientAuthSession {
  final String token;
  final ClientUser user;

  const ClientAuthSession({
    required this.token,
    required this.user,
  });
}

class UserAuthRepository {
  final ApiClient _apiClient = ApiClient();

  Future<String> uploadAvatar(XFile image) async {
    final bytes = await image.readAsBytes();
    final lowerName = image.name.toLowerCase();
    final contentType = lowerName.endsWith('.png')
        ? 'image/png'
        : lowerName.endsWith('.webp')
            ? 'image/webp'
            : 'image/jpeg';
    final response = await _apiClient.request(
      '/uploads/avatar/sign',
      method: 'POST',
      data: {
        'files': [
          {
            'fileName': image.name,
            'contentType': contentType,
            'size': bytes.length,
          },
        ],
      },
    );
    final upload = Map<String, dynamic>.from(response.data['upload'] as Map);
    final fields = Map<String, dynamic>.from(upload['fields'] as Map);
    await _apiClient.uploadForm(
      upload['uploadUrl'] as String,
      FormData.fromMap({
        ...fields,
        'file': MultipartFile.fromBytes(bytes, filename: image.name),
      }),
    );
    return upload['url'] as String;
  }

  Future<String?> requestSmsCode({required String phone}) async {
    final response = await _apiClient.request(
      '/auth/sms/request',
      method: 'POST',
      data: {'phone': phone},
    );
    final data = Map<String, dynamic>.from(response.data);
    return data['debugCode']?.toString();
  }

  Future<ClientAuthSession> verifySmsCode({
    required String phone,
    required String code,
  }) async {
    final response = await _apiClient.request(
      '/auth/sms/verify',
      method: 'POST',
      data: {
        'phone': phone,
        'code': code,
      },
    );
    return _sessionFromResponse(Map<String, dynamic>.from(response.data));
  }

  Future<ClientAuthSession> updateProfile({
    required String displayName,
    required String gender,
    required String phone,
    required String avatarUrl,
  }) async {
    final response = await _apiClient.request(
      '/auth/profile',
      method: 'PATCH',
      data: {
        'displayName': displayName,
        'gender': gender,
        'phone': phone,
        'avatarUrl': avatarUrl,
      },
    );
    return _sessionFromResponse(Map<String, dynamic>.from(response.data));
  }

  Future<ClientAuthSession> login({
    required String account,
    required String password,
  }) async {
    final response = await _apiClient.request(
      '/auth/login',
      method: 'POST',
      data: {
        'account': account,
        'password': password,
      },
    );
    return _sessionFromResponse(Map<String, dynamic>.from(response.data));
  }

  Future<ClientAuthSession> register({
    required String account,
    required String password,
    required String displayName,
  }) async {
    final response = await _apiClient.request(
      '/auth/register',
      method: 'POST',
      data: {
        'account': account,
        'password': password,
        'displayName': displayName,
      },
    );
    return _sessionFromResponse(Map<String, dynamic>.from(response.data));
  }

  Future<List<Map<String, dynamic>>> fetchCoupons() async {
    final response = await _apiClient.request('/auth/coupons');
    return (response.data as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  ClientAuthSession _sessionFromResponse(Map<String, dynamic> data) {
    final token = data['token']?.toString() ?? '';
    final user = ClientUser.fromJson(Map<String, dynamic>.from(data['user']));
    ApiClient.authToken = token;
    return ClientAuthSession(token: token, user: user);
  }
}
