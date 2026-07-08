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
    final imagePayload = await _imagePayload(images);

    await _apiClient.request(
      '/bookings/$bookingId/review',
      method: 'POST',
      data: {
        'rating': rating,
        'comment': comment,
        if (imagePayload.isNotEmpty) 'images': imagePayload,
      },
    );
  }

  Future<void> submitComplaint({
    required String bookingId,
    required String description,
    required List<XFile> images,
  }) async {
    final imagePayload = await _imagePayload(images);

    await _apiClient.request(
      '/bookings/$bookingId/complaint',
      method: 'POST',
      data: {
        'description': description,
        if (imagePayload.isNotEmpty) 'images': imagePayload,
      },
    );
  }

  Future<List<Map<String, String>>> _imagePayload(List<XFile> images) async {
    final payload = <Map<String, String>>[];

    for (final image in images.take(5)) {
      final bytes = await image.readAsBytes();
      payload.add({
        'fileName': image.name,
        'mimeType': image.mimeType ?? 'image/jpeg',
        'data': base64Encode(bytes),
      });
    }

    return payload;
  }
}
