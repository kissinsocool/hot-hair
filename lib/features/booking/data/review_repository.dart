import 'dart:convert';

import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';

class ReviewRepository {
  final ApiClient _apiClient = ApiClient();

  Future<void> submitReview({
    required String bookingId,
    required int rating,
    required String comment,
    required List<XFile> images,
  }) async {
    final imagePayload = <Map<String, String>>[];

    for (final image in images.take(5)) {
      final bytes = await image.readAsBytes();
      imagePayload.add({
        'fileName': image.name,
        'data': base64Encode(bytes),
      });
    }

    await _apiClient.request(
      '/bookings/$bookingId/review',
      method: 'POST',
      data: {
        'rating': rating,
        'comment': comment,
        'images': imagePayload,
      },
    );
  }

  Future<void> submitComplaint({
    required String bookingId,
    required String description,
    required List<XFile> images,
  }) async {
    final imagePayload = <Map<String, String>>[];

    for (final image in images.take(5)) {
      final bytes = await image.readAsBytes();
      imagePayload.add({
        'fileName': image.name,
        'data': base64Encode(bytes),
      });
    }

    await _apiClient.request(
      '/bookings/$bookingId/complaint',
      method: 'POST',
      data: {
        'description': description,
        'images': imagePayload,
      },
    );
  }
}
