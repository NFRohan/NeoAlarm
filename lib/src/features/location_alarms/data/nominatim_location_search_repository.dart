import 'dart:convert';
import 'dart:io';

import 'package:neoalarm/src/features/location_alarms/data/location_search_repository.dart';
import 'package:neoalarm/src/features/location_alarms/domain/location_search_result.dart';

class NominatimLocationSearchRepository implements LocationSearchRepository {
  const NominatimLocationSearchRepository();

  @override
  Future<List<LocationSearchResult>> search(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return const [];
    }

    final client = HttpClient();
    try {
      final request = await client.getUrl(
        Uri.https(
          'nominatim.openstreetmap.org',
          '/search',
          {
            'q': trimmedQuery,
            'format': 'jsonv2',
            'limit': '8',
          },
        ),
      );
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'NeoAlarm/1.0.3 (+https://github.com/NFRohan/NeoAlarm)',
      );
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');

      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const LocationSearchException(
          'Location search is temporarily unavailable.',
        );
      }

      final body = await utf8.decodeStream(response);
      return NominatimLocationSearchParser.parse(body);
    } on SocketException {
      throw const LocationSearchException(
        'No network connection. Location search needs internet access.',
      );
    } on FormatException {
      throw const LocationSearchException(
        'Location search returned an unexpected response.',
      );
    } finally {
      client.close(force: true);
    }
  }
}

class NominatimLocationSearchParser {
  static List<LocationSearchResult> parse(String body) {
    final raw = jsonDecode(body);
    if (raw is! List) {
      throw const FormatException('Expected a list of search results.');
    }

    return raw
        .whereType<Map>()
        .map((entry) => _parseResult(entry.cast<Object?, Object?>()))
        .whereType<LocationSearchResult>()
        .toList(growable: false);
  }

  static LocationSearchResult? _parseResult(Map<Object?, Object?> raw) {
    final displayName = raw['display_name'] as String?;
    final latitude = double.tryParse('${raw['lat'] ?? ''}');
    final longitude = double.tryParse('${raw['lon'] ?? ''}');

    if (displayName == null || latitude == null || longitude == null) {
      return null;
    }

    return LocationSearchResult(
      label: displayName,
      latitude: latitude,
      longitude: longitude,
    );
  }
}
