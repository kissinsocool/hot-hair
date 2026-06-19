// -------------------------------------------------------------------------
// 彻底移除所有 part '...' 声明，避免依赖代码生成工具 build_runner
// -------------------------------------------------------------------------

class TimeSlot {
  final String time; // 例如 "10:00"
  final DateTime startTime; // 实际的 DateTime 对象，方便计算
  final bool isAvailable; // 是否可用
  final String? reason; // 不可用原因

  TimeSlot({
    required this.time,
    required this.startTime,
    required this.isAvailable,
    this.reason,
  });
}

class SalonService {
  final String id;
  final String name;
  final int durationMinutes;
  final String imageUrl;
  final String note;
  final String priceLabel;

  SalonService({
    required this.id,
    required this.name,
    required this.durationMinutes,
    this.imageUrl = '',
    this.note = '',
    this.priceLabel = '',
  });
}
