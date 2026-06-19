import '../../../core/network/api_client.dart';
import '../domain/booking_order.dart';

class OrderRepository {
  final ApiClient _apiClient = ApiClient();

  Future<List<BookingOrder>> fetchUserBookings() async {
    final response = await _apiClient.request('/bookings');
    final data = response.data as List;
    return data
        .map((item) => BookingOrder.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<BookingOrder> cancelBooking(String bookingId) async {
    final response = await _apiClient.request(
      '/bookings/$bookingId/cancel',
      method: 'PATCH',
    );
    return BookingOrder.fromJson(
      Map<String, dynamic>.from(response.data['booking']),
    );
  }
}
