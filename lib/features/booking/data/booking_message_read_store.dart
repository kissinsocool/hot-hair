import 'package:shared_preferences/shared_preferences.dart';

import '../domain/booking_order.dart';

class BookingMessageReadStore {
  static const _readMessageKeyKey = 'booking_read_message_key';
  static String? _readMessageKey;

  static Future<void> restore() async {
    final preferences = await SharedPreferences.getInstance();
    _readMessageKey = preferences.getString(_readMessageKeyKey);
  }

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

  static Future<void> markRead(String? messageKey) async {
    if (messageKey == null) return;
    _readMessageKey = messageKey;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_readMessageKeyKey, messageKey);
  }
}
