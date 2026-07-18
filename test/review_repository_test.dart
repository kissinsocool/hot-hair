import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hot_hair_app/features/booking/data/review_repository.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

void main() {
  test('review images are resized and encoded as quality-35 JPEG', () async {
    final source = img.Image(width: 1600, height: 800);
    img.fill(source, color: img.ColorRgb8(180, 80, 120));
    final images = await prepareReviewImages([
      XFile.fromData(
        Uint8List.fromList(img.encodePng(source)),
        name: 'review.png',
        mimeType: 'image/png',
      ),
    ]);

    expect(images.single.contentType, 'image/jpeg');
    expect(images.single.fileName, 'image.jpg');
    final compressed = img.decodeJpg(images.single.bytes)!;
    expect(compressed.width, reviewImageMaxDimension);
    expect(compressed.height, 640);
    expect(images.single.bytes.length, lessThan(reviewImageMaxBytes));
  });

  test('invalid review images are rejected', () async {
    final image = XFile.fromData(
      Uint8List(128),
      name: 'invalid.jpg',
      mimeType: 'image/jpeg',
    );

    await expectLater(
      prepareReviewImages([image]),
      throwsA(isA<ReviewImageSizeException>()),
    );
  });

  test('only five review images are prepared', () async {
    final bytes = Uint8List.fromList(
      img.encodeJpg(img.Image(width: 4, height: 4)),
    );
    final files = List.generate(
      6,
      (index) => XFile.fromData(
        bytes,
        name: 'review-$index.jpg',
        mimeType: 'image/jpeg',
      ),
    );

    expect(await prepareReviewImages(files), hasLength(5));
  });
}
