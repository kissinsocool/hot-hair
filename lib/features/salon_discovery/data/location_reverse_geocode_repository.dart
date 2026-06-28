import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';

class LocationReverseGeocodeRepository {
  static const _amapKey = String.fromEnvironment(
    'AMAP_WEB_KEY',
    defaultValue: '2285f50755ccb6f5339886b84b2c4039',
  );

  final ApiClient _apiClient = ApiClient();
  final Dio _dio = Dio();

  Future<List<Map<String, dynamic>>> fetchAddressSuggestions({
    required String keyword,
    double? latitude,
    double? longitude,
  }) async {
    try {
      final response = await _apiClient.request(
        '/location/suggestions',
        queryParameters: {
          'keyword': keyword,
          if (latitude != null) 'latitude': latitude,
          if (longitude != null) 'longitude': longitude,
        },
      );
      final suggestions = parseAddressSuggestions(response.data);
      if (suggestions.isNotEmpty) return suggestions;
    } catch (_) {
      return [];
    }
    return [];
  }

  Future<String?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    final response = await _dio.get(
      'https://restapi.amap.com/v3/geocode/regeo',
      queryParameters: {
        'key': _amapKey,
        'location': '$longitude,$latitude',
        'extensions': 'base',
        'output': 'json',
      },
    );
    return parseAmapReverseAddress(response.data);
  }
}

String? parseAmapReverseAddress(dynamic data) {
  final raw = data is Map ? data['regeocode'] : null;
  if (raw is! Map) return null;

  final address = raw['formatted_address']?.toString().trim() ?? '';
  if (address.isNotEmpty) return address;

  final component = raw['addressComponent'];
  if (component is! Map) return null;

  return [
    component['province'],
    component['city'],
    component['district'],
    component['township'],
  ]
      .map((part) => part?.toString().trim() ?? '')
      .where((part) => part.isNotEmpty)
      .join();
}

List<Map<String, dynamic>> parseAddressSuggestions(dynamic data) {
  final raw = data is List
      ? data
      : data is Map
          ? data['data'] ?? data['suggestions'] ?? data['pois'] ?? []
          : [];

  return raw
      .whereType<Map>()
      .map<Map<String, dynamic>>(
          (item) => normalizeAddressSuggestion(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}

Map<String, dynamic> normalizeAddressSuggestion(Map<String, dynamic> item) {
  final lonlat = (item['lonlat'] ?? item['lonLat'])?.toString().split(',');
  if (lonlat != null && lonlat.length >= 2) {
    item['longitude'] ??= lonlat[0].trim();
    item['latitude'] ??= lonlat[1].trim();
  }
  item['city'] ??= item['cityname'];
  item['district'] ??= item['county'] ?? item['areaName'];
  item['address'] ??= item['addressName'];
  return item;
}
