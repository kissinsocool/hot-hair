import 'package:flutter_test/flutter_test.dart';
import 'package:hot_hair_app/features/booking/presentation/booking_screen.dart';

void main() {
  test('matches salon closed dates by calendar day', () {
    const closedDates = ['2026-07-18'];

    expect(isClosedBookingDate(DateTime(2026, 7, 18), closedDates), isTrue);
    expect(isClosedBookingDate(DateTime(2026, 7, 19), closedDates), isFalse);
  });
}
