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
  final List<String> noPreferenceCandidateStaffIds;
  final bool isLoading;

  BookingState({
    this.availableSlots = const [],
    this.selectedService,
    this.selectedStaff,
    this.selectedDate,
    this.selectedTime,
    this.noPreferenceCandidateStaffIds = const [],
    this.isLoading = false,
  });

  BookingState copyWith({
    List<TimeSlot>? availableSlots,
    SalonService? selectedService,
    StaffProfile? selectedStaff,
    DateTime? selectedDate,
    String? selectedTime,
    List<String>? noPreferenceCandidateStaffIds,
    bool? isLoading,
    bool clearSelectedTime = false,
  }) {
    return BookingState(
      availableSlots: availableSlots ?? this.availableSlots,
      selectedService: selectedService ?? this.selectedService,
      selectedStaff: selectedStaff ?? this.selectedStaff,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedTime:
          clearSelectedTime ? null : selectedTime ?? this.selectedTime,
      noPreferenceCandidateStaffIds:
          noPreferenceCandidateStaffIds ?? this.noPreferenceCandidateStaffIds,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class BookingNotifier extends StateNotifier<BookingState> {
  BookingNotifier() : super(BookingState());

  final ApiClient _apiClient = ApiClient();

  Future<void> loadAvailableSlots(
    DateTime date,
    String staffId, {
    List<String> candidateStaffIds = const [],
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final dateStr = date.toIso8601String().split('T')[0];
      final candidateQuery = candidateStaffIds.isEmpty
          ? ''
          : '&candidateStaffIds=${candidateStaffIds.join(',')}';
      final response = await _apiClient
          .request('/staff/$staffId/slots?date=$dateStr$candidateQuery');
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

      state = state.copyWith(availableSlots: slots, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
    }
  }

  void selectService(SalonService service) {
    state = state.copyWith(selectedService: service);
  }

  void selectStaff(StaffProfile staff) {
    state = state.copyWith(selectedStaff: staff);
  }

  void setNoPreferenceCandidateStaffIds(List<String> staffIds) {
    state = state.copyWith(noPreferenceCandidateStaffIds: staffIds);
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

  Future<bool> confirmBooking(
    String staffId,
    String serviceId,
    String time, {
    List<String> candidateStaffIds = const [],
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
      serviceId: serviceId,
      startTime: startTime,
      candidateStaffIds: candidateStaffIds,
    );
    return booking != null;
  }

  Future<BookingOrder?> createBooking({
    required String staffId,
    required String serviceId,
    required DateTime startTime,
    List<String> candidateStaffIds = const [],
  }) async {
    try {
      final response = await _apiClient.request(
        '/bookings',
        method: 'POST',
        data: {
          'staffId': staffId,
          'serviceId': serviceId,
          'startTime': startTime.toIso8601String(),
          if (candidateStaffIds.isNotEmpty)
            'candidateStaffIds': candidateStaffIds,
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
