import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hot_hair_app/features/booking/data/review_repository.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  test('review images are encoded within per-file and total limits', () async {
    final payload = await buildReviewImagePayload([
      XFile.fromData(Uint8List(128),
          name: 'review.jpg', mimeType: 'image/jpeg'),
    ]);

    expect(payload.single['mimeType'], 'image/jpeg');
    expect(payload.single['data'], isNotEmpty);
  });

  test('review images over 800 kilobytes are rejected', () async {
    final image = XFile.fromData(
      Uint8List(reviewImageMaxBytes + 1),
      name: 'large.jpg',
      mimeType: 'image/jpeg',
    );

    await expectLater(
      buildReviewImagePayload([image]),
      throwsA(isA<ReviewImageSizeException>()),
    );
  });

  test('review image payload over four megabytes is rejected', () async {
    final images = List.generate(
      5,
      (index) => XFile.fromData(
        Uint8List(900 * 1024),
        name: 'review-$index.jpg',
        mimeType: 'image/jpeg',
      ),
    );

    await expectLater(
      buildReviewImagePayload(images),
      throwsA(isA<ReviewImageSizeException>()),
    );
  });
}
