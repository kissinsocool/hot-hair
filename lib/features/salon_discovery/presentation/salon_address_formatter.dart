String formatSalonCityAddress(dynamic address) {
  final text = address?.toString().trim() ?? '';
  if (text.isEmpty) return '地址未知';

  final cityMatch = RegExp(r'^(.+?市)').firstMatch(text);
  if (cityMatch != null) return cityMatch.group(1)!;

  final commaIndex = text.indexOf(',');
  if (commaIndex > 0) return text.substring(0, commaIndex).trim();

  return text;
}
