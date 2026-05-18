import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:neoalarm/src/core/app/app_metadata.dart';
import 'package:neoalarm/src/features/location_alarms/data/location_search_repository.dart';
import 'package:neoalarm/src/features/location_alarms/domain/location_search_result.dart';

class PhotonLocationSearchRepository implements LocationSearchRepository {
  const PhotonLocationSearchRepository();

  static const _endpointHost = 'photon.komoot.io';
  static const _networkTimeout = Duration(seconds: 8);
  static const _maxResponseBytes = 512 * 1024;

  @override
  Future<List<LocationSearchResult>> search(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) {
      return const [];
    }

    final client = HttpClient();
    client.connectionTimeout = _networkTimeout;
    try {
      final request = await client
          .getUrl(
            Uri.https(_endpointHost, '/api', {
              'q': trimmedQuery,
              'limit': '8',
              'lang': 'en',
            }),
          )
          .timeout(_networkTimeout);
      request.headers.set(HttpHeaders.userAgentHeader, AppMetadata.userAgent);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');

      final response = await request.close().timeout(_networkTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const LocationSearchException(
          'Location search is temporarily unavailable.',
        );
      }

      final body = await _readResponseBody(response);
      return PhotonLocationSearchParser.parse(body);
    } on TimeoutException {
      throw const LocationSearchException(
        'Location search timed out. Please try again.',
      );
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

  static Future<String> _readResponseBody(HttpClientResponse response) async {
    final bytes = BytesBuilder(copy: false);
    var totalBytes = 0;
    await for (final chunk in response.timeout(_networkTimeout)) {
      totalBytes += chunk.length;
      if (totalBytes > _maxResponseBytes) {
        throw const FormatException('Photon response exceeded size cap.');
      }
      bytes.add(chunk);
    }
    return utf8.decode(bytes.takeBytes());
  }
}

class PhotonLocationSearchParser {
  static List<LocationSearchResult> parse(String body) {
    final raw = jsonDecode(body);
    if (raw is! Map<Object?, Object?>) {
      throw const FormatException('Expected a Photon feature collection.');
    }

    final features = raw['features'];
    if (features is! List) {
      throw const FormatException('Expected a Photon feature list.');
    }

    return features
        .whereType<Map<Object?, Object?>>()
        .map(_parseResult)
        .whereType<LocationSearchResult>()
        .toList(growable: false);
  }

  static LocationSearchResult? _parseResult(Map<Object?, Object?> raw) {
    final properties = raw['properties'];
    final geometry = raw['geometry'];
    if (properties is! Map || geometry is! Map) {
      return null;
    }

    final coordinates = geometry['coordinates'];
    if (coordinates is! List || coordinates.length < 2) {
      return null;
    }

    final longitude = _asDouble(coordinates[0]);
    final latitude = _asDouble(coordinates[1]);
    if (latitude == null || longitude == null) {
      return null;
    }

    final label = _buildLabel(properties.cast<Object?, Object?>());
    if (label == null || label.isEmpty) {
      return null;
    }

    return LocationSearchResult(
      label: label,
      latitude: latitude,
      longitude: longitude,
    );
  }

  static String? _buildLabel(Map<Object?, Object?> properties) {
    final parts = <String>[];
    final name = _stringOrNull(properties['name']);
    if (name != null) {
      parts.add(name);
    }

    for (final key in const [
      'district',
      'suburb',
      'city',
      'state',
      'country',
    ]) {
      final value = _stringOrNull(properties[key]);
      if (value != null && !parts.contains(value)) {
        parts.add(value);
      }
    }

    if (parts.isEmpty) {
      return _stringOrNull(properties['country']);
    }

    return parts.join(', ');
  }

  static String? _stringOrNull(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) {
      return null;
    }
    return text;
  }

  static double? _asDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    return double.tryParse('$value');
  }
}
