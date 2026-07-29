import 'dart:async';

import 'package:csp_amap_flutter_location/amap_flutter_location.dart';
import 'package:csp_amap_flutter_location/amap_location_option.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationPositionService {
  LocationPositionService._();

  static const _androidKey = String.fromEnvironment(
    'AMAP_ANDROID_KEY',
    defaultValue: '7adb51802cef1a73ad8b2250c8f46e72',
  );
  static const _iosKey = String.fromEnvironment(
    'AMAP_IOS_KEY',
    defaultValue: '834625b89e475e766cc5c5e3bd5c3cc8',
  );
  static const _cachedPositionMaxAge = Duration(minutes: 5);
  static bool _configured = false;

  static Future<Position> currentPosition() async {
    if (kIsWeb && !isSecureBrowserLocationOrigin(Uri.base)) {
      throw Exception('浏览器定位需要 HTTPS 或 localhost，请手动选择地址');
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('定位服务未开启');

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('未获得定位权限');
    }

    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    }

    final cachedPosition = await Geolocator.getLastKnownPosition();
    if (cachedPosition != null &&
        DateTime.now().difference(cachedPosition.timestamp) <=
            _cachedPositionMaxAge) {
      return cachedPosition;
    }

    _configureAmap();
    Object? amapError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        return await _currentAmapPosition();
      } catch (error) {
        amapError = error;
        if (attempt == 1) break;
        // ponytail: Android AMap can miss right after permission grant; one retry mirrors the manual re-locate path.
        await Future<void>.delayed(const Duration(milliseconds: 300));
      }
    }

    debugPrint('高德定位失败，切换系统定位: $amapError');
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 8),
      ),
    );
  }

  static Future<Position> _currentAmapPosition() async {
    final location = AMapFlutterLocation();
    try {
      location.setLocationOption(AMapLocationOption(
        onceLocation: true,
        needAddress: false,
        locatingWithReGeocode: false,
        geoLanguage: GeoLanguage.ZH,
        locationMode: AMapLocationMode.Hight_Accuracy,
        desiredAccuracy: DesiredAccuracy.HundredMeters,
      ));
      final resultFuture = location
          .onLocationChanged()
          .first
          .timeout(const Duration(seconds: 8));
      location.startLocation();
      final result = await resultFuture;
      final position = positionFromAmapResult(result);
      location.stopLocation();
      return position;
    } on TimeoutException {
      throw Exception('定位超时，请重试');
    } finally {
      location.destroy();
    }
  }

  static void _configureAmap() {
    if (_configured) return;
    AMapFlutterLocation.updatePrivacyShow(true, true);
    AMapFlutterLocation.updatePrivacyAgree(true);
    AMapFlutterLocation.setApiKey(_androidKey, _iosKey);
    _configured = true;
  }
}

bool isSecureBrowserLocationOrigin(Uri uri) {
  final host = uri.host.toLowerCase();
  return uri.scheme == 'https' ||
      host == 'localhost' ||
      host.endsWith('.localhost') ||
      host == '127.0.0.1' ||
      host == '::1';
}

Position positionFromAmapResult(Map<String, Object> result) {
  final error = result['errorInfo']?.toString();
  if (error != null && error.isNotEmpty) throw Exception(error);

  final latitude = double.tryParse(result['latitude']?.toString() ?? '');
  final longitude = double.tryParse(result['longitude']?.toString() ?? '');
  if (latitude == null || longitude == null) {
    throw Exception('定位结果无效');
  }

  return Position(
    latitude: latitude,
    longitude: longitude,
    timestamp: DateTime.tryParse(
          result['locationTime']?.toString() ??
              result['locTime']?.toString() ??
              '',
        ) ??
        DateTime.now(),
    accuracy: double.tryParse(result['accuracy']?.toString() ?? '') ?? 0,
    altitude: double.tryParse(result['altitude']?.toString() ?? '') ?? 0,
    altitudeAccuracy: 0,
    heading: double.tryParse(result['bearing']?.toString() ?? '') ?? 0,
    headingAccuracy: 0,
    speed: double.tryParse(result['speed']?.toString() ?? '') ?? 0,
    speedAccuracy: 0,
  );
}
