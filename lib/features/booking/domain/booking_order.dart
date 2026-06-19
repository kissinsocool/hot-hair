class BookingOrder {
  final String id;
  final String userId;
  final String userName;
  final String salonId;
  final String salonName;
  final String staffName;
  final String serviceName;
  final String servicePrice;
  final String serviceDuration;
  final int serviceBasePrice;
  final int staffExtraServiceFee;
  final int totalPrice;
  final DateTime startTime;
  final String status;
  final String statusLabel;
  final String userMessage;
  final String merchantMessage;
  final String? rejectReason;
  final bool reviewed;
  final bool complained;
  final DateTime createdAt;
  final DateTime updatedAt;

  BookingOrder({
    required this.id,
    required this.userId,
    required this.userName,
    required this.salonId,
    required this.salonName,
    required this.staffName,
    required this.serviceName,
    required this.servicePrice,
    required this.serviceDuration,
    this.serviceBasePrice = 0,
    this.staffExtraServiceFee = 0,
    this.totalPrice = 0,
    required this.startTime,
    required this.status,
    required this.statusLabel,
    required this.userMessage,
    required this.merchantMessage,
    this.rejectReason,
    this.reviewed = false,
    this.complained = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BookingOrder.fromJson(Map<String, dynamic> json) {
    return BookingOrder(
      id: json['id'] as String,
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      salonId: json['salonId']?.toString() ?? '',
      salonName: json['salonName'] as String,
      staffName: json['staffName'] as String,
      serviceName: json['serviceName'] as String,
      servicePrice: json['servicePrice'] as String? ?? '',
      serviceDuration: json['serviceDuration'] as String? ?? '',
      serviceBasePrice: _parseInt(json['serviceBasePrice']),
      staffExtraServiceFee: _parseInt(json['staffExtraServiceFee']),
      totalPrice: _parseInt(json['totalPrice']),
      startTime: DateTime.parse(json['startTime'] as String).toLocal(),
      status: json['status'] as String,
      statusLabel: json['statusLabel'] as String? ?? json['status'] as String,
      userMessage: json['userMessage'] as String? ?? '',
      merchantMessage: json['merchantMessage'] as String? ?? '',
      rejectReason: json['rejectReason'] as String?,
      reviewed: json['reviewed'] as bool? ?? false,
      complained: json['complained'] as bool? ?? false,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toLocal(),
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
