import 'package:geocoding/geocoding.dart';

String formatLocationLeafAddress(String value) {
  final text = value.trim();
  if (text.isEmpty) return text;

  final withoutLocatePrefix =
      text.startsWith('定位到：') ? text.substring(4).trim() : text;
  const statusPrefixes = ['正在', '已获取', '定位', '未获得', '需要'];
  if (statusPrefixes.any(withoutLocatePrefix.startsWith) ||
      withoutLocatePrefix.contains('(')) {
    return withoutLocatePrefix;
  }

  final separatedParts = withoutLocatePrefix
      .split(RegExp(r'[,\，;；|｜·\s]+'))
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toList();
  if (separatedParts.length > 1) return separatedParts.last;

  final lastAdministrativeBoundary = RegExp(r'(省|自治区|特别行政区|市|区|县|自治县|旗|自治旗)')
      .allMatches(withoutLocatePrefix)
      .fold<int>(-1, (index, match) => match.end > index ? match.end : index);
  final localAddress = lastAdministrativeBoundary > -1 &&
          lastAdministrativeBoundary < withoutLocatePrefix.length
      ? withoutLocatePrefix.substring(lastAdministrativeBoundary).trim()
      : withoutLocatePrefix;
  final lastStreetBoundary = RegExp(r'(街道|镇|乡)')
      .allMatches(localAddress)
      .fold<int>(-1, (index, match) => match.end > index ? match.end : index);
  final detailAddress =
      lastStreetBoundary > -1 && lastStreetBoundary < localAddress.length
          ? localAddress.substring(lastStreetBoundary).trim()
          : localAddress;

  final communityMatches = RegExp(
    r'[\u4e00-\u9fa5A-Za-z0-9]+(?:小区|花园|公寓|家园|新村|社区|苑|里|府|湾|城|广场|中心|大厦)',
  ).allMatches(detailAddress).toList();
  if (communityMatches.isNotEmpty) {
    return communityMatches.last.group(0)!.trim();
  }

  final roadMatches = RegExp(
    r'[\u4e00-\u9fa5A-Za-z0-9]+(?:路|街|巷|弄)',
  ).allMatches(detailAddress).toList();
  if (roadMatches.isNotEmpty) {
    return roadMatches.last.group(0)!.trim();
  }

  final streetBoundaryMatches = RegExp(
    r'[\u4e00-\u9fa5A-Za-z0-9]+(?:街道|镇|乡|路|街|巷|弄)',
  ).allMatches(localAddress).toList();
  if (streetBoundaryMatches.isNotEmpty) {
    return streetBoundaryMatches.last.group(0)!.trim();
  }

  return localAddress;
}

String formatPlacemarkAddress(Placemark place) {
  final parts = <String?>[
    place.administrativeArea,
    place.locality,
    place.subAdministrativeArea,
    place.subLocality,
    place.thoroughfare,
    place.subThoroughfare,
    place.name,
  ]
      .map((part) => part?.trim() ?? '')
      .where((part) => part.isNotEmpty)
      .fold<List<String>>([], (items, part) {
    if (items.isEmpty || !items.last.contains(part)) {
      items.add(part);
    }
    return items;
  });

  return parts.join('');
}
