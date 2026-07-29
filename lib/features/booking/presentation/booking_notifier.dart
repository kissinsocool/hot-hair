import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../domain/booking_model.dart';
import '../domain/booking_order.dart';
import '../domain/staff_model.dart';

class BookingState {
  final List<TimeSlot> availableSlots;
  final SalonService? selectedService;
  final StaffProfile? selectedStaff;
  final DateTime? selectedDate;
  final String? selectedTime;
  final String salonId;
  final bool isLoading;
  final String slotError;

  BookingState({
    this.availableSlots = const [],
    this.selectedService,
    this.selectedStaff,
    this.selectedDate,
    this.selectedTime,
    this.salonId = '',
    this.isLoading = false,
    this.slotError = '',
  });

  BookingState copyWith({
    List<TimeSlot>? availableSlots,
    SalonService? selectedService,
    StaffProfile? selectedStaff,
    DateTime? selectedDate,
    String? selectedTime,
    String? salonId,
    bool? isLoading,
    String? slotError,
    bool clearSelectedTime = false,
  }) {
    return BookingState(
      availableSlots: availableSlots ?? this.availableSlots,
      selectedService: selectedService ?? this.selectedService,
      selectedStaff: selectedStaff ?? this.selectedStaff,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedTime:
          clearSelectedTime ? null : selectedTime ?? this.selectedTime,
      salonId: salonId ?? this.salonId,
      isLoading: isLoading ?? this.isLoading,
      slotError: slotError ?? this.slotError,
    );
  }
}

class BookingNotifier extends StateNotifier<BookingState> {
  BookingNotifier() : super(BookingState());

  final ApiClient _apiClient = ApiClient();

  Future<void> loadAvailableSlots(
    DateTime date,
    String staffId, {
    String salonId = '',
  }) async {
    if (staffId == '__no_preference__' && salonId.isEmpty) {
      state = state.copyWith(
        availableSlots: const [],
        isLoading: false,
        slotError: '缺少门店信息，请返回门店详情后重新预约',
      );
      return;
    }
    state = state.copyWith(isLoading: true, slotError: '');
    try {
      final dateStr = date.toIso8601String().split('T')[0];
      final salonQuery = staffId == '__no_preference__'
          ? '&salonId=${Uri.encodeQueryComponent(salonId)}'
          : '';
      final response = await _apiClient
          .request('/staff/$staffId/slots?date=$dateStr$salonQuery');
      final data = response.data as List;

      final now = DateTime.now();
      final slots = data.map((item) {
        final startTime = DateTime.parse(item['startTime'] as String);
        final isPast = !startTime.isAfter(now);

        return TimeSlot(
          time: item['time'] as String,
          startTime: startTime,
          isAvailable: !isPast && (item['isAvailable'] as bool),
          reason: isPast ? '已过' : item['reason'],
        );
      }).toList();

      state = state.copyWith(
        availableSlots: slots,
        isLoading: false,
        slotError: '',
      );
    } catch (e) {
      state = state.copyWith(
        availableSlots: const [],
        isLoading: false,
        slotError: ApiClient.errorMessage(e, fallback: '可用时间段加载失败，请稍后重试'),
      );
    }
  }

  void selectService(SalonService service) {
    state = state.copyWith(selectedService: service);
  }

  void selectStaff(StaffProfile staff) {
    state = state.copyWith(selectedStaff: staff);
  }

  void setSalonId(String salonId) {
    state = state.copyWith(salonId: salonId);
  }

  void selectDate(DateTime date) {
    state = state.copyWith(selectedDate: date);
  }

  void selectTime(String time) {
    state = state.copyWith(selectedTime: time);
  }

  void clearSelectedTime() {
    state = state.copyWith(clearSelectedTime: true);
  }

  void clearAvailableSlots() {
    state = state.copyWith(
      availableSlots: const [],
      isLoading: false,
      slotError: '',
      clearSelectedTime: true,
    );
  }

  void resetForSalon(String salonId) {
    state = BookingState(salonId: salonId);
  }

  Future<bool> confirmBooking(
    String staffId,
    String serviceId,
    String time, {
    String couponId = '',
  }) async {
    if (state.selectedDate == null) return false;

    final parts = time.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final startTime = DateTime(
      state.selectedDate!.year,
      state.selectedDate!.month,
      state.selectedDate!.day,
      hour,
      minute,
    );
    if (!startTime.isAfter(DateTime.now())) return false;

    final booking = await createBooking(
      staffId: staffId,
      salonId: state.salonId,
      serviceId: serviceId,
      startTime: startTime,
      couponId: couponId,
    );
    return booking != null;
  }

  Future<BookingOrder?> createBooking({
    required String staffId,
    required String salonId,
    required String serviceId,
    required DateTime startTime,
    String couponId = '',
  }) async {
    try {
      final response = await _apiClient.request(
        '/bookings',
        method: 'POST',
        data: {
          'staffId': staffId,
          'salonId': salonId,
          'serviceId': serviceId,
          'startTime': startTime.toIso8601String(),
          if (couponId.isNotEmpty) 'couponId': couponId,
        },
      );
      if (response.statusCode == 201) {
        return BookingOrder.fromJson(
            Map<String, dynamic>.from(response.data['booking']));
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}

final bookingProvider =
    StateNotifierProvider<BookingNotifier, BookingState>((ref) {
  return BookingNotifier();
});
