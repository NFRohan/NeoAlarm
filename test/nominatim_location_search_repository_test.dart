import 'package:flutter_test/flutter_test.dart';
import 'package:neoalarm/src/features/location_alarms/data/nominatim_location_search_repository.dart';

void main() {
  test('parses Nominatim search results into domain models', () {
    const body = '''
[
  {
    "display_name": "Banani Station, Dhaka, Bangladesh",
    "lat": "23.7937",
    "lon": "90.4066"
  },
  {
    "display_name": "Dhanmondi 27, Dhaka, Bangladesh",
    "lat": "23.7465",
    "lon": "90.3760"
  }
]
''';

    final results = NominatimLocationSearchParser.parse(body);

    expect(results, hasLength(2));
    expect(results.first.label, 'Banani Station, Dhaka, Bangladesh');
    expect(results.first.latitude, 23.7937);
    expect(results.first.longitude, 90.4066);
  });

  test('ignores malformed Nominatim entries', () {
    const body = '''
[
  {
    "display_name": "Good result",
    "lat": "23.7",
    "lon": "90.4"
  },
  {
    "display_name": "Missing lon",
    "lat": "23.8"
  }
]
''';

    final results = NominatimLocationSearchParser.parse(body);

    expect(results, hasLength(1));
    expect(results.single.label, 'Good result');
  });
}
