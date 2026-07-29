import '../../../core/network/api_client.dart';

class SalonRepository {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> fetchAdCampaign() async {
    try {
      final response = await _apiClient.request('/ad');
      final data = Map<String, dynamic>.from(response.data);
      return {
        'enabled': data['enabled'] != false,
        'imageUrl': ApiClient.mediaUrl(data['imageUrl']?.toString() ?? ''),
      };
    } catch (_) {
      return const {'enabled': true, 'imageUrl': ''};
    }
  }

  Future<List<Map<String, dynamic>>> fetchSalons({
    required double latitude,
    required double longitude,
  }) async {
    final response = await _apiClient.request(
      '/salons',
      queryParameters: {
        'latitude': latitude,
        'longitude': longitude,
      },
    );
    return List<Map<String, dynamic>>.from(
      response.data,
    ).map(_normalizeSalonImages).toList();
  }

  Future<List<Map<String, dynamic>>> fetchSalonSuggestions({
    required String keyword,
    double? latitude,
    double? longitude,
  }) async {
    final response = await _apiClient.request(
      '/salons/suggestions',
      queryParameters: {
        'keyword': keyword,
        if (latitude != null) 'latitude': latitude,
        if (longitude != null) 'longitude': longitude,
      },
    );
    return List<Map<String, dynamic>>.from(
      response.data,
    ).map(_normalizeSalonImages).toList();
  }

  Future<Map<String, dynamic>> fetchSalonDetail(String id) async {
    final response = await _apiClient.request('/salons/$id');
    return _normalizeSalonImages(Map<String, dynamic>.from(response.data));
  }

  Map<String, dynamic> _normalizeSalonImages(Map<String, dynamic> salon) {
    String media(dynamic value) => ApiClient.mediaUrl(value?.toString() ?? '');
    List<String> mediaList(dynamic value) => value is List
        ? value.map(media).where((url) => url.isNotEmpty).toList()
        : const [];

    salon['image'] = media(salon['image']);
    salon['promoImages'] = mediaList(salon['promoImages']);
    salon['images'] = mediaList(salon['images']);
    for (final service in (salon['services'] as List?) ?? const []) {
      if (service is Map) service['imageUrl'] = media(service['imageUrl']);
    }
    for (final staff in (salon['staff'] as List?) ?? const []) {
      if (staff is Map) {
        staff['imageUrl'] = media(staff['imageUrl']);
        for (final review in (staff['reviews'] as List?) ?? const []) {
          if (review is Map) {
            review['imageUrls'] = mediaList(review['imageUrls']);
          }
        }
      }
    }
    for (final review in (salon['reviews'] as List?) ?? const []) {
      if (review is Map) review['imageUrls'] = mediaList(review['imageUrls']);
    }
    return salon;
  }
}
