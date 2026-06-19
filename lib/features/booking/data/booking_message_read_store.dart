import '../domain/booking_order.dart';

class BookingMessageReadStore {
  static String? _readMessageKey;

  static String? latestMessageKey(List<BookingOrder> orders) {
    if (orders.isEmpty) return null;

    final sortedOrders = [...orders]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final latest = sortedOrders.first;
    return '${latest.id}:${latest.status}:${latest.updatedAt.toIso8601String()}';
  }

  static bool hasUnreadMessages(List<BookingOrder> orders) {
    final key = latestMessageKey(orders);
    return key != null && key != _readMessageKey;
  }

  static void markRead(String? messageKey) {
    if (messageKey == null) return;
    _readMessageKey = messageKey;
  }
}
