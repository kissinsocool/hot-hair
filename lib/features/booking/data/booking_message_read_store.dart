import 'package:shared_preferences/shared_preferences.dart';

import '../domain/booking_order.dart';

class BookingMessageReadStore {
  static const _readMessageKeyKey = 'booking_read_message_key';
  static String? _readMessageKey;

  static Future<void> restore() async {
    final preferences = await SharedPreferences.getInstance();
    _readMessageKey = preferences.getString(_readMessageKeyKey);
  }

  static String? messageStateKey(List<BookingOrder> orders) {
    if (orders.isEmpty) return null;

    final messageStates =
        orders.map((order) => '${order.id}:${order.status}').toList()..sort();
    return messageStates.join('|');
  }

  static bool hasUnreadMessages(List<BookingOrder> orders) {
    final key = messageStateKey(orders);
    return key != null && key != _readMessageKey;
  }

  static Future<void> markRead(String? messageKey) async {
    if (messageKey == null) return;
    _readMessageKey = messageKey;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_readMessageKeyKey, messageKey);
  }
}
