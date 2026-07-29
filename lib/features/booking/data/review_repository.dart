import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_client.dart';

const int reviewImageMaxBytes = 800 * 1024;
const int reviewImageMaxDimension = 1280;
const int reviewImageQuality = 35;

class ReviewImageSizeException implements Exception {
  const ReviewImageSizeException(this.message);

  final String message;
}

class PreparedReviewImage {
  const PreparedReviewImage({
    required this.fileName,
    required this.contentType,
    required this.bytes,
  });

  final String fileName;
  final String contentType;
  final Uint8List bytes;
}

Future<List<PreparedReviewImage>> prepareReviewImages(
  List<XFile> images,
) async {
  final prepared = <PreparedReviewImage>[];

  for (final image in images.take(5)) {
    final bytes =
        await compute(_compressReviewImage, await image.readAsBytes());
    if (bytes.isEmpty) {
      throw const ReviewImageSizeException('无法读取所选图片，请重新选择');
    }
    if (bytes.length > reviewImageMaxBytes) {
      throw const ReviewImageSizeException('单张图片压缩后仍超过 800 KB，请重新选择');
    }
    final extensionIndex = image.name.lastIndexOf('.');
    final baseName = extensionIndex > 0
        ? image.name.substring(0, extensionIndex)
        : image.name;
    prepared.add(PreparedReviewImage(
      fileName: '${baseName.isEmpty ? 'image' : baseName}.jpg',
      contentType: 'image/jpeg',
      bytes: bytes,
    ));
  }

  return prepared;
}

Uint8List _compressReviewImage(Uint8List source) {
  var image = img.decodeImage(source);
  if (image == null) return Uint8List(0);
  image = img.bakeOrientation(image);
  if (image.width > reviewImageMaxDimension ||
      image.height > reviewImageMaxDimension) {
    image = image.width >= image.height
        ? img.copyResize(image, width: reviewImageMaxDimension)
        : img.copyResize(image, height: reviewImageMaxDimension);
  }
  final flattened = img.Image(
    width: image.width,
    height: image.height,
    numChannels: 3,
  );
  img.fill(flattened, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(flattened, image);
  return Uint8List.fromList(
    img.encodeJpg(flattened, quality: reviewImageQuality),
  );
}

class ReviewRepository {
  final ApiClient _apiClient = ApiClient();

  Future<List<Map<String, dynamic>>> fetchMyReviews() async {
    final data = await _apiClient.requestAllPages('/auth/reviews');
    return data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<void> submitReview({
    required String bookingId,
    required int rating,
    required String comment,
    required List<XFile> images,
  }) async {
    final imageObjects = await _uploadImages(images, 'review');

    await _apiClient.request(
      '/bookings/$bookingId/review',
      method: 'POST',
      data: {
        'rating': rating,
        'comment': comment,
        if (imageObjects.isNotEmpty) 'imageObjects': imageObjects,
      },
    );
  }

  Future<void> updateReview({
    required String bookingId,
    required int rating,
    required String comment,
    required List<String> retainedImageUrls,
    required List<XFile> images,
  }) async {
    final imageObjects = await _uploadImages(images, 'review');
    await _apiClient.request(
      '/bookings/$bookingId/review',
      method: 'PATCH',
      data: {
        'rating': rating,
        'comment': comment,
        'retainedImageUrls': retainedImageUrls,
        if (imageObjects.isNotEmpty) 'imageObjects': imageObjects,
      },
    );
  }

  Future<void> deleteReview(String bookingId) async {
    await _apiClient.request(
      '/bookings/$bookingId/review',
      method: 'DELETE',
    );
  }

  Future<void> submitComplaint({
    required String bookingId,
    required String description,
    required List<XFile> images,
  }) async {
    final imageObjects = await _uploadImages(images, 'complaint');

    await _apiClient.request(
      '/bookings/$bookingId/complaint',
      method: 'POST',
      data: {
        'description': description,
        if (imageObjects.isNotEmpty) 'imageObjects': imageObjects,
      },
    );
  }

  Future<List<String>> _uploadImages(List<XFile> images, String type) async {
    final prepared = await prepareReviewImages(images);
    if (prepared.isEmpty) return [];

    final response = await _apiClient.request(
      '/uploads/moderation/sign',
      method: 'POST',
      data: {
        'type': type,
        'files': prepared
            .map((image) => {
                  'fileName': image.fileName,
                  'contentType': image.contentType,
                  'size': image.bytes.length,
                })
            .toList(),
      },
    );
    final uploads = (response.data['uploads'] as List?) ?? const [];
    if (uploads.length != prepared.length) {
      throw StateError('图片上传凭证数量不正确');
    }

    await Future.wait(List.generate(prepared.length, (index) {
      final upload = Map<String, dynamic>.from(uploads[index] as Map);
      final fields = Map<String, dynamic>.from(upload['fields'] as Map);
      return _apiClient.uploadForm(
        upload['uploadUrl'] as String,
        FormData.fromMap({
          ...fields,
          'file': MultipartFile.fromBytes(
            prepared[index].bytes,
            filename: prepared[index].fileName,
          ),
        }),
      );
    }));

    return uploads
        .map((upload) => (upload as Map)['objectName'] as String)
        .toList();
  }
}
