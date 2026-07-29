import 'package:flutter_test/flutter_test.dart';
import 'package:hot_hair_app/features/booking/data/booking_message_read_store.dart';
import 'package:hot_hair_app/features/booking/domain/booking_order.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await BookingMessageReadStore.restore();
  });

  test('restores read booking message key', () async {
    final order = _order(updatedAt: DateTime(2026));

    expect(BookingMessageReadStore.hasUnreadMessages([order]), isTrue);

    await BookingMessageReadStore.markRead(
      BookingMessageReadStore.messageStateKey([order]),
    );
    await BookingMessageReadStore.restore();

    expect(BookingMessageReadStore.hasUnreadMessages([order]), isFalse);
  });

  test('booking metadata updates do not create unread messages', () async {
    final order = _order(updatedAt: DateTime(2026));
    await BookingMessageReadStore.markRead(
      BookingMessageReadStore.messageStateKey([order]),
    );

    final reviewDeletedOrder = _order(
      updatedAt: DateTime(2026, 1, 2),
      reviewed: false,
    );

    expect(
      BookingMessageReadStore.hasUnreadMessages([reviewDeletedOrder]),
      isFalse,
    );
  });

  test('new bookings and status changes create unread messages', () async {
    final order = _order(updatedAt: DateTime(2026));
    await BookingMessageReadStore.markRead(
      BookingMessageReadStore.messageStateKey([order]),
    );

    expect(
      BookingMessageReadStore.hasUnreadMessages([
        order,
        _order(id: '2', updatedAt: DateTime(2026, 1, 2)),
      ]),
      isTrue,
    );
    expect(
      BookingMessageReadStore.hasUnreadMessages([
        _order(updatedAt: DateTime(2026, 1, 2), status: 'rejected'),
      ]),
      isTrue,
    );
  });
}

BookingOrder _order({
  String id = '1',
  required DateTime updatedAt,
  String status = 'accepted',
  bool reviewed = true,
}) {
  return BookingOrder(
    id: id,
    userId: 'u1',
    userName: '用户',
    salonId: 's1',
    salonName: '沙龙',
    staffName: '理发师',
    serviceName: '剪发',
    servicePrice: '¥100',
    serviceDuration: '60分钟',
    startTime: updatedAt,
    status: status,
    statusLabel: '已接单',
    userMessage: '',
    merchantMessage: '',
    reviewed: reviewed,
    createdAt: updatedAt,
    updatedAt: updatedAt,
  );
}
