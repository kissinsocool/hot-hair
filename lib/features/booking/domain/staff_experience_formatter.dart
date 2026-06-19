String formatStaffExperience(String experience) {
  final text = experience.trim();
  if (text.isEmpty) return text;
  if (text.contains('专业经验')) return text;
  if (text.contains('经验')) return text.replaceFirst('经验', '专业经验');
  return '$text专业经验';
}
