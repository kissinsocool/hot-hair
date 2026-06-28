import '../../../core/network/api_client.dart';

class SalonRepository {
  final ApiClient _apiClient = ApiClient();

  Future<List<Map<String, dynamic>>> fetchSalons() async {
    try {
      final response = await _apiClient.request('/salons');
      return List<Map<String, dynamic>>.from(response.data);
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
      return List<Map<String, dynamic>>.from(response.data);
    } catch (e) {
      throw Exception('Failed to load salon suggestions: ${e.toString()}');
    }
  }

  Future<Map<String, dynamic>> fetchSalonDetail(String id) async {
    try {
      final response = await _apiClient.request('/salons/$id');
      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      throw Exception('Failed to load salon detail: ${e.toString()}');
    }
  }
}
