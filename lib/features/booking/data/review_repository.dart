import 'dart:convert';

import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';

const int reviewImageMaxBytes = 800 * 1024;
const int reviewImagesMaxBytes = 4 * 1024 * 1024;

class ReviewImageSizeException implements Exception {
  const ReviewImageSizeException(this.message);

  final String message;
}

Future<List<Map<String, String>>> buildReviewImagePayload(
  List<XFile> images,
) async {
  final payload = <Map<String, String>>[];
  var totalBytes = 0;

  for (final image in images.take(5)) {
    final bytes = await image.readAsBytes();
    if (bytes.length > reviewImageMaxBytes) {
      throw const ReviewImageSizeException('单张图片压缩后仍超过 800 KB，请重新选择');
    }
    totalBytes += bytes.length;
    if (totalBytes > reviewImagesMaxBytes) {
      throw const ReviewImageSizeException('图片总大小不能超过 4 MB');
    }
    payload.add({
      'fileName': image.name,
      'mimeType': image.mimeType ?? 'image/jpeg',
      'data': base64Encode(bytes),
    });
  }

  return payload;
}

class ReviewRepository {
  final ApiClient _apiClient = ApiClient();

  Future<void> submitReview({
    required String bookingId,
    required int rating,
    required String comment,
    required List<XFile> images,
  }) async {
    final imagePayload = await buildReviewImagePayload(images);

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
    final imagePayload = await buildReviewImagePayload(images);

    await _apiClient.request(
      '/bookings/$bookingId/complaint',
      method: 'POST',
      data: {
        'description': description,
        if (imagePayload.isNotEmpty) 'images': imagePayload,
      },
    );
  }
}
