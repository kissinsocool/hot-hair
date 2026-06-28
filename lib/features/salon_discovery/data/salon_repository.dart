import '../../../core/network/api_client.dart';

class SalonRepository {
  final ApiClient _apiClient = ApiClient();

  Future<List<Map<String, dynamic>>> fetchSalons() async {
    try {
      final response = await _apiClient.request('/salons');
      return List<Map<String, dynamic>>.from(
        response.data,
      ).map(_normalizeSalonImages).toList();
    } catch (e) {
      throw Exception('Failed to load salons: ${e.toString()}');
    }
  }

  Future<List<Map<String, dynamic>>> fetchSalonSuggestions({
    required String keyword,
    double? latitude,
    double? longitude,
  }) async {
    try {
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
    } catch (e) {
      throw Exception('Failed to load salon suggestions: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> fetchSalonDetail(String id) async {
    try {
      final response = await _apiClient.request('/salons/$id');
      return _normalizeSalonImages(Map<String, dynamic>.from(response.data));
    } catch (e) {
      throw Exception('Failed to load salon detail: ${e.toString()}');
    }
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
      if (staff is Map) staff['imageUrl'] = media(staff['imageUrl']);
    }
    for (final review in (salon['reviews'] as List?) ?? const []) {
      if (review is Map) review['imageUrls'] = mediaList(review['imageUrls']);
    }
    return salon;
  }
}
