import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/router.dart';
import 'booking_notifier.dart';
import '../domain/booking_model.dart';
import '../domain/staff_experience_formatter.dart';
import '../domain/staff_model.dart';

bool isClosedBookingDate(DateTime date, Iterable<String> closedDates) {
  final dateKey = '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
  return closedDates.contains(dateKey);
}

bool isSameDayBookingDateUnavailable(
  DateTime date,
  bool acceptsSameDayBooking, {
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  return !acceptsSameDayBooking &&
      date.year == today.year &&
      date.month == today.month &&
      date.day == today.day;
}

class BookingScreen extends ConsumerStatefulWidget {
  final String salonId;
  final List<StaffProfile>? initialStaffList;
  final List<SalonService>? initialServices;
  final String? preferredStaffId;
  final String? initialServiceId;
  final List<String> closedDates;
  final bool acceptsSameDayBooking;

  const BookingScreen(
      {super.key,
      this.salonId = '',
      this.initialStaffList,
      this.initialServices,
      this.preferredStaffId,
      this.initialServiceId,
      this.closedDates = const [],
      this.acceptsSameDayBooking = true});

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  static const String _noPreferenceStaffId = '__no_preference__';
  static final StaffProfile _noPreferenceStaff = StaffProfile(
    id: _noPreferenceStaffId,
    name: '无需指定',
    role: '',
    experience: '',
    extraServiceFee: 0,
    imageUrl: '',
    bio: '',
    rating: 5,
    reviews: const [],
  );

  String? selectedStaffId;
  String? selectedTimeSlot;
  DateTime? selectedDate;

  late List<StaffProfile> staffList;
  late List<SalonService> staffServices;

  List<StaffProfile> get _staffOptions => [
        _noPreferenceStaff,
        ...staffList,
      ];

  @override
  void initState() {
    super.initState();
    staffList = widget.initialStaffList ?? mockStaffList;
    staffServices = widget.initialServices ??
        [
          SalonService(id: 's1', name: '极简剪发', durationMinutes: 60),
          SalonService(id: 's2', name: '高级染发', durationMinutes: 120),
          SalonService(id: 's3', name: '深层护理', durationMinutes: 180),
          SalonService(id: 's4', name: '全套造型', durationMinutes: 240),
        ];

    if (widget.preferredStaffId != null) {
      selectedStaffId = widget.preferredStaffId;
    } else if (staffList.isNotEmpty) {
      selectedStaffId = _noPreferenceStaffId;
    }

    for (final date in _generateWeekDates()) {
      if (!_isUnavailableDate(date)) {
        selectedDate = date;
        break;
      }
    }

    Future.microtask(() {
      ref.read(bookingProvider.notifier).resetForSalon(widget.salonId);
      if (selectedStaffId != null) {
        final staff = _staffOptions.firstWhere((s) => s.id == selectedStaffId);
        ref.read(bookingProvider.notifier).selectStaff(staff);
      }
      if (widget.initialServiceId != null) {
        for (final service in staffServices) {
          if (service.id == widget.initialServiceId) {
            ref.read(bookingProvider.notifier).selectService(service);
            break;
          }
        }
      }
      if (selectedDate != null) {
        ref.read(bookingProvider.notifier).selectDate(selectedDate!);
        _loadSlotsForDate(selectedDate!);
      }
    });
  }

  void _loadSlotsForDate(DateTime date) {
    if (selectedStaffId == null) return;
    ref.read(bookingProvider.notifier).loadAvailableSlots(
          date,
          selectedStaffId!,
          salonId: widget.salonId,
        );
  }

  void _clearSelectedTime() {
    setState(() => selectedTimeSlot = null);
    ref.read(bookingProvider.notifier).clearSelectedTime();
  }

  List<DateTime> _generateWeekDates() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return List.generate(
        7, (i) => DateTime(today.year, today.month, today.day + i));
  }

  bool _isClosedDate(DateTime date) =>
      isClosedBookingDate(date, widget.closedDates);

  bool _isSameDayUnavailable(DateTime date) =>
      isSameDayBookingDateUnavailable(date, widget.acceptsSameDayBooking);

  bool _isUnavailableDate(DateTime date) =>
      _isClosedDate(date) || _isSameDayUnavailable(date);

  @override
  Widget build(BuildContext context) {
    final bookingState = ref.watch(bookingProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgCream,
      appBar: AppBar(
        title: Text('预约时间',
            style: TextStyle(
                color: AppTheme.textDark, fontWeight: FontWeight.bold)),
        backgroundColor: AppTheme.white,
        elevation: 0,
        iconTheme: IconThemeData(color: AppTheme.textDark),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          10,
          10,
          10,
          MediaQuery.sizeOf(context).height * 0.2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('请完成以下预约选项',
                style: TextStyle(fontSize: 16, color: Colors.grey[600])),
            SizedBox(height: 25),
            Text('选择理发师',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark)),
            SizedBox(height: 15),
            ..._staffOptions
                .map((staff) => _buildStaffSelector(staff))
                .toList(),
            SizedBox(height: 30),
            Text('选择服务项目',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark)),
            SizedBox(height: 15),
            ...staffServices
                .map((service) => _buildServiceItem(
                    service, bookingState.selectedService?.id))
                .toList(),
            SizedBox(height: 30),
            Text('选择预约日期',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark)),
            SizedBox(height: 15),
            SizedBox(
              height: 96,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _generateWeekDates()
                    .map((date) => _buildDateItem(date))
                    .toList(),
              ),
            ),
            SizedBox(height: 25),
            Text('可用时间段',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark)),
            SizedBox(height: 15),
            if (bookingState.isLoading)
              Center(
                  child: Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: CircularProgressIndicator(color: AppTheme.primaryPink),
              ))
            else if (bookingState.slotError.isNotEmpty)
              Center(
                child: Column(
                  children: [
                    Text(
                      bookingState.slotError,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    if (selectedDate != null)
                      TextButton(
                        onPressed: () => _loadSlotsForDate(selectedDate!),
                        child: Text('重新加载'),
                      ),
                  ],
                ),
              )
            else if (bookingState.availableSlots.isEmpty)
              Center(
                child: Text(
                  selectedDate == null ? '未来七天均为休息日' : '当天暂无可用时间段',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              )
            else
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: bookingState.availableSlots
                    .map((slot) => ChoiceChip(
                          label: Text(
                            slot.isAvailable
                                ? slot.time
                                : '${slot.time}\n${_formatUnavailableReason(slot.reason)}',
                            textAlign: TextAlign.center,
                          ),
                          selected:
                              slot.isAvailable && selectedTimeSlot == slot.time,
                          selectedColor: AppTheme.primaryPink,
                          disabledColor: Colors.grey[300],
                          labelStyle: TextStyle(
                            color: slot.isAvailable
                                ? (selectedTimeSlot == slot.time
                                    ? Colors.white
                                    : AppTheme.textDark)
                                : Colors.grey,
                            fontSize: slot.isAvailable ? 14 : 12,
                            height: 1.15,
                          ),
                          onSelected: slot.isAvailable
                              ? (val) {
                                  setState(() => selectedTimeSlot =
                                      val ? slot.time : null);
                                  if (selectedTimeSlot != null) {
                                    ref
                                        .read(bookingProvider.notifier)
                                        .selectTime(selectedTimeSlot!);
                                  } else {
                                    ref
                                        .read(bookingProvider.notifier)
                                        .clearSelectedTime();
                                  }
                                }
                              : null,
                        ))
                    .toList(),
              ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
          10,
          10,
          10,
          MediaQuery.paddingOf(context).bottom + 9,
        ),
        color: AppTheme.white,
        child: SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton(
            onPressed: (selectedStaffId != null &&
                    selectedDate != null &&
                    bookingState.selectedService != null &&
                    selectedTimeSlot != null)
                ? () => context.push(AppRouter.confirm)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryPink,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
            ),
            child: Text(
              selectedStaffId == null
                  ? '请选择理发师'
                  : (selectedDate == null
                      ? '请选择营业日期'
                      : (bookingState.selectedService == null
                          ? '请选择服务项目'
                          : (selectedTimeSlot == null ? '请选择时间段' : '确认预约'))),
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStaffSelector(StaffProfile staff) {
    final isSelected = selectedStaffId == staff.id;
    final isNoPreference = staff.id == _noPreferenceStaffId;
    final isAssetImage = staff.imageUrl.startsWith('assets/');
    final experience =
        formatStaffExperience(staff.experience).split('|').first.trim();

    return GestureDetector(
      onTap: () {
        setState(() => selectedStaffId = staff.id);
        _clearSelectedTime();
        ref.read(bookingProvider.notifier).selectStaff(staff);
        if (selectedDate != null) _loadSlotsForDate(selectedDate!);
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 6),
        padding: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isSelected ? AppTheme.primaryPink : AppTheme.accentBeige),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: Offset(0, 4))
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 104,
              height: 130,
              color: isNoPreference
                  ? AppTheme.primaryPink.withOpacity(0.12)
                  : Colors.grey[200],
              child: isNoPreference
                  ? Icon(
                      Icons.question_mark,
                      color: AppTheme.primaryPink,
                      size: 36,
                    )
                  : isAssetImage
                      ? AppImages.placeholder(width: 104, height: 130)
                      : Image.network(
                          staff.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              AppImages.placeholder(width: 104, height: 130),
                        ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: isNoPreference
                  ? Text(
                      '无需指定',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.textDark,
                      ),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(staff.name,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: AppTheme.textDark)),
                            ),
                            if (staff.extraServiceFee > 0) ...[
                              SizedBox(width: 8),
                              Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 3, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '+¥${staff.extraServiceFee}',
                                  style: TextStyle(
                                    color: Color(0xFFD4AF37),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          experience.isEmpty
                              ? staff.role
                              : '${staff.role}（$experience）',
                          style:
                              TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                        if (staff.bio.isNotEmpty) ...[
                          SizedBox(height: 8),
                          Text(
                            staff.bio,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: AppTheme.textDark,
                                fontSize: 14,
                                height: 1.35),
                          ),
                        ],
                      ],
                    ),
            ),
            SizedBox(width: 8),
            Icon(Icons.check_circle,
                color: isSelected ? AppTheme.primaryPink : Colors.grey[300],
                size: 24),
          ],
        ),
      ),
    );
  }

  String _formatUnavailableReason(String? reason) {
    return switch (reason) {
      '理发师缺勤' => '缺勤',
      '店铺休息日' => '休息',
      '已过' => '已过',
      _ => '已约',
    };
  }

  Widget _buildDateItem(DateTime date) {
    final isSelected = selectedDate == date;
    final isClosed = _isClosedDate(date);
    final isUnavailable = isClosed || _isSameDayUnavailable(date);
    return GestureDetector(
      onTap: isUnavailable
          ? null
          : () {
              setState(() => selectedDate = date);
              _clearSelectedTime();
              ref.read(bookingProvider.notifier).selectDate(date);
              _loadSlotsForDate(selectedDate!);
            },
      child: Container(
        width: 60,
        margin: EdgeInsets.only(right: 5),
        decoration: BoxDecoration(
          color: isUnavailable
              ? Colors.grey[200]
              : isSelected
                  ? AppTheme.primaryPink
                  : AppTheme.bgCream,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isUnavailable
                  ? Colors.grey[300]!
                  : isSelected
                      ? AppTheme.primaryPink
                      : AppTheme.accentBeige),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(DateFormat('EEE').format(date),
                style: TextStyle(
                    fontSize: 12,
                    color: isSelected ? Colors.white70 : Colors.grey)),
            SizedBox(height: 4),
            Text(DateFormat('dd').format(date),
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isUnavailable
                        ? Colors.grey
                        : isSelected
                            ? Colors.white
                            : AppTheme.textDark)),
            if (isClosed) ...[
              SizedBox(height: 4),
              Text(
                '休息日',
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildServiceItem(SalonService service, String? selectedId) {
    final isSelected = service.id == selectedId;
    return GestureDetector(
      onTap: () {
        ref.read(bookingProvider.notifier).selectService(service);
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 6),
        padding: EdgeInsets.all(7.5),
        decoration: BoxDecoration(
          color: AppTheme.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
              color: isSelected ? AppTheme.primaryPink : AppTheme.accentBeige),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 10,
                offset: Offset(0, 4))
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildServiceImage(service.imageUrl),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(service.name,
                      style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                          color: AppTheme.textDark)),
                  if (service.note.isNotEmpty) ...[
                    SizedBox(height: 5),
                    Text(
                      service.note,
                      style: TextStyle(
                          color: Colors.grey[600], fontSize: 14, height: 1.35),
                    ),
                  ],
                  SizedBox(height: 6),
                  Text('${service.durationMinutes} min',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
            ),
            SizedBox(width: 12),
            Row(
              children: [
                if (service.priceLabel.isNotEmpty) ...[
                  Text(
                    service.priceLabel,
                    style: TextStyle(
                        color: AppTheme.primaryPink,
                        fontWeight: FontWeight.bold,
                        fontSize: 15),
                  ),
                  SizedBox(width: 15),
                ],
                Icon(
                  Icons.check_circle,
                  color: isSelected ? AppTheme.primaryPink : Colors.grey[300],
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceImage(String imageUrl) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 72,
        height: 72,
        color: Colors.grey[200],
        child: imageUrl.isEmpty
            ? AppImages.placeholder(width: 72, height: 72)
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    AppImages.placeholder(width: 72, height: 72),
              ),
      ),
    );
  }
}
