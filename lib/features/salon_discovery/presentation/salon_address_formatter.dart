String formatSalonCityAddress(dynamic salonOrAddress) {
  if (salonOrAddress is Map) {
    final region = salonOrAddress['addressRegion'];
    final districtName =
        region is Map ? (region['districtName']?.toString().trim() ?? '') : '';
    final detail = salonOrAddress['addressDetail']?.toString().trim() ?? '';
    if (districtName.isNotEmpty && detail.isNotEmpty) {
      return detail.startsWith(districtName) ? detail : '$districtName$detail';
    }
    if (districtName.isNotEmpty) return districtName;
    if (detail.isNotEmpty) return detail;
    salonOrAddress = salonOrAddress['address'];
  }

  final text = salonOrAddress?.toString().trim() ?? '';
  if (text.isEmpty) return '地址未知';

  final commaParts = text
      .split(RegExp(r'[,，]'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  if (commaParts.length > 1) {
    final cityIndex = commaParts.indexWhere((part) => part.endsWith('市'));
    final localParts = cityIndex > 0
        ? commaParts.take(cityIndex).toList()
        : commaParts
            .where(
              (part) =>
                  !RegExp(r'^\d+$').hasMatch(part) &&
                  part != '中国' &&
                  !part.endsWith('省') &&
                  !part.endsWith('市'),
            )
            .toList();
    if (localParts.isNotEmpty) return localParts.reversed.join('');
  }

  final withoutProvinceCity =
      text.replaceFirst(RegExp(r'^(?:[^省]+省)?[^市]+市'), '').trim();
  if (withoutProvinceCity.isNotEmpty && withoutProvinceCity != text) {
    return withoutProvinceCity;
  }

  final withoutProvince = text.replaceFirst(RegExp(r'^[^省]+省'), '').trim();
  if (withoutProvince.isNotEmpty && withoutProvince != text) {
    return withoutProvince;
  }

  return text;
}
