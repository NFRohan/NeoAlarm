import 'package:flutter_test/flutter_test.dart';
import 'package:neoalarm/src/features/location_alarms/data/photon_location_search_repository.dart';

void main() {
  test('parses Photon search results into domain models', () {
    const body = '''
{
  "features": [
    {
      "geometry": {
        "coordinates": [90.4066, 23.7937]
      },
      "properties": {
        "name": "Banani Station",
        "city": "Dhaka",
        "country": "Bangladesh"
      }
    },
    {
      "geometry": {
        "coordinates": [90.3760, 23.7465]
      },
      "properties": {
        "name": "Dhanmondi 27",
        "city": "Dhaka",
        "country": "Bangladesh"
      }
    }
  ]
}
''';

    final results = PhotonLocationSearchParser.parse(body);

    expect(results, hasLength(2));
    expect(results.first.label, 'Banani Station, Dhaka, Bangladesh');
    expect(results.first.latitude, 23.7937);
    expect(results.first.longitude, 90.4066);
  });

  test('ignores malformed Photon entries', () {
    const body = '''
{
  "features": [
    {
      "geometry": {
        "coordinates": [90.4, 23.7]
      },
      "properties": {
        "name": "Good result",
        "country": "Bangladesh"
      }
    },
    {
      "properties": {
        "name": "Missing geometry"
      }
    }
  ]
}
''';

    final results = PhotonLocationSearchParser.parse(body);

    expect(results, hasLength(1));
    expect(results.single.label, 'Good result, Bangladesh');
  });
}
