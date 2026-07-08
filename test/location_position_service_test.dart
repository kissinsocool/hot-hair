import 'package:flutter_test/flutter_test.dart';
import 'package:hot_pepper_clone/features/salon_discovery/data/location_position_service.dart';

void main() {
  test('detects browser origins that can use geolocation', () {
    expect(isSecureBrowserLocationOrigin(Uri.parse('https://example.com')),
        isTrue);
    expect(isSecureBrowserLocationOrigin(Uri.parse('http://localhost:8080')),
        isTrue);
    expect(isSecureBrowserLocationOrigin(Uri.parse('http://192.168.1.46')),
        isFalse);
  });

  test('parses AMap location result into Position', () {
    final position = positionFromAmapResult({
      'latitude': '31.23536',
      'longitude': '121.50109',
      'accuracy': 12.5,
      'altitude': '8',
      'bearing': '90',
      'speed': '1.5',
      'locTime': '2026-06-27 17:40:25',
    });

    expect(position.latitude, 31.23536);
    expect(position.longitude, 121.50109);
    expect(position.accuracy, 12.5);
    expect(position.heading, 90);
    expect(position.speed, 1.5);
  });
}
