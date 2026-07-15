import 'package:flutter_test/flutter_test.dart';
import 'package:hot_hair_app/features/salon_discovery/data/location_reverse_geocode_repository.dart';

void main() {
  test('parses AMap reverse geocode address', () {
    final address = parseAmapReverseAddress({
      'status': '1',
      'regeocode': {
        'formatted_address': '上海市浦东新区陆家嘴街道银城中路501号',
      },
    });

    expect(address, '上海市浦东新区陆家嘴街道银城中路501号');
  });

  test('parses poi suggestions', () {
    final suggestions = parseAddressSuggestions({
      'pois': [
        {
          'name': '上海中心大厦',
          'address': '银城中路501号',
          'lonlat': '121.50109,31.23536',
          'cityname': '上海市',
          'county': '浦东新区',
        }
      ],
    });

    expect(suggestions.single['longitude'], '121.50109');
    expect(suggestions.single['latitude'], '31.23536');
    expect(suggestions.single['city'], '上海市');
    expect(suggestions.single['district'], '浦东新区');
  });
}
