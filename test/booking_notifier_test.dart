import 'package:flutter_test/flutter_test.dart';
import 'package:hot_hair_app/features/booking/domain/booking_model.dart';
import 'package:hot_hair_app/features/booking/presentation/booking_notifier.dart';

void main() {
  test('starting a booking for another salon clears the previous service', () {
    final notifier = BookingNotifier();
    notifier.selectService(SalonService(
      id: '99',
      name: '旧店套餐',
      durationMinutes: 60,
    ));

    notifier.resetForSalon('cuffia');

    expect(notifier.state.salonId, 'cuffia');
    expect(notifier.state.selectedService, isNull);
  });

  test('no-preference slots require a salon id', () async {
    final notifier = BookingNotifier();

    await notifier.loadAvailableSlots(
      DateTime(2030, 1, 1),
      '__no_preference__',
    );

    expect(notifier.state.availableSlots, isEmpty);
    expect(notifier.state.slotError, contains('缺少门店信息'));
  });
}
