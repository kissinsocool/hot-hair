import '../domain/booking_model.dart';
import '../../../core/network/api_client.dart';

class BookingRepository {
  BookingRepository(ApiClient apiClient);

  // 获取特定发型师在特定日期的所有预约
  Future<List<TimeSlot>> fetchBookingsForStaff(
      String staffId, DateTime date) async {
    // 模拟 API 调用
    // final response = await _apiClient.request('/bookings?staffId=$staffId&date=${date.toIso8601String()}');

    // 生成半小时一个间隔的时间段 (09:00 - 21:00)
    List<TimeSlot> allSlots = [];
    for (int hour = 9; hour < 21; hour++) {
      for (int minute = 0; minute < 60; minute += 30) {
        String timeStr =
            '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
        allSlots.add(TimeSlot(
          time: timeStr,
          startTime: DateTime(date.year, date.month, date.day, hour, minute),
          isAvailable: true,
        ));
      }
    }

    // 模拟一些已占用时间段
    final occupiedTimes = ['11:00', '15:30', '18:00'];
    return allSlots.map((slot) {
      if (occupiedTimes.contains(slot.time)) {
        return TimeSlot(
          time: slot.time,
          startTime: slot.startTime,
          isAvailable: false,
          reason: '已预约',
        );
      }
      return slot;
    }).toList();
  }

  // 提交预约单
  Future<bool> createBooking({
    required String userId,
    required String staffId,
    required String serviceId,
    required DateTime startTime,
  }) async {
    // 模拟发送 POST 请求
    // await _apiClient.request('/bookings', method: 'POST', data: {...});
    return true;
  }
}
