import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';

class FavoriteSalonStore {
  FavoriteSalonStore._();

  static final ApiClient _apiClient = ApiClient();

  static final ValueNotifier<List<Map<String, dynamic>>> favorites =
      ValueNotifier<List<Map<String, dynamic>>>([]);

  static Future<void> load() async {
    try {
      final response = await _apiClient.request('/favorites');
      if (response.data is! List) return;
      favorites.value = (response.data as List)
          .whereType<Map>()
          .map((salon) => Map<String, dynamic>.from(salon))
          .toList();
    } catch (_) {
      favorites.value = [];
    }
  }

  static bool isFavorite(String salonId) {
    return favorites.value.any((salon) => salon['id'].toString() == salonId);
  }

  static Future<void> toggle(Map<String, dynamic> salon) async {
    final salonId = salon['id'].toString();
    final previousFavorites = favorites.value;
    final nextFavorites = [...favorites.value];
    final index =
        nextFavorites.indexWhere((item) => item['id'].toString() == salonId);

    if (index >= 0) {
      nextFavorites.removeAt(index);
    } else {
      nextFavorites.insert(0, Map<String, dynamic>.from(salon));
    }

    favorites.value = nextFavorites;
    try {
      final response = await _apiClient.request(
        '/favorites/toggle',
        method: 'POST',
        data: salon,
      );
      if (response.data is List) {
        favorites.value = (response.data as List)
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
    } catch (_) {
      favorites.value = previousFavorites;
      rethrow;
    }
  }
}
