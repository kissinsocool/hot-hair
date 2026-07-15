import 'package:flutter_test/flutter_test.dart';
import 'package:hot_hair_app/features/booking/data/booking_message_read_store.dart';
import 'package:hot_hair_app/features/booking/domain/booking_order.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('restores read booking message key', () async {
    SharedPreferences.setMockInitialValues({});
    final order = _order(updatedAt: DateTime(2026));

    expect(BookingMessageReadStore.hasUnreadMessages([order]), isTrue);

    await BookingMessageReadStore.markRead(
      BookingMessageReadStore.latestMessageKey([order]),
    );
    await BookingMessageReadStore.restore();

    expect(BookingMessageReadStore.hasUnreadMessages([order]), isFalse);
  });
}

BookingOrder _order({required DateTime updatedAt}) {
  return BookingOrder(
    id: '1',
    userId: 'u1',
    userName: '用户',
    salonId: 's1',
    salonName: '沙龙',
    staffName: '理发师',
    serviceName: '剪发',
    servicePrice: '¥100',
    serviceDuration: '60分钟',
    startTime: updatedAt,
    status: 'accepted',
    statusLabel: '已接单',
    userMessage: '',
    merchantMessage: '',
    createdAt: updatedAt,
    updatedAt: updatedAt,
  );
}
