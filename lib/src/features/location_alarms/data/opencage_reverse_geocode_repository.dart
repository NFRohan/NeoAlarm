import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:neoalarm/src/core/app/app_metadata.dart';
import 'package:neoalarm/src/features/location_alarms/data/location_reverse_geocode_repository.dart';

class OpenCageReverseGeocodeRepository
    implements LocationReverseGeocodeRepository {
  const OpenCageReverseGeocodeRepository({required this.apiKey});

  final String apiKey;
  static const _networkTimeout = Duration(seconds: 8);
  static const _maxResponseBytes = 256 * 1024;

  @override
  Future<String?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    final client = HttpClient();
    client.connectionTimeout = _networkTimeout;
    try {
      final request = await client
          .getUrl(
            Uri.https('api.opencagedata.com', '/geocode/v1/json', {
              'q': '$latitude,$longitude',
              'key': apiKey,
              'limit': '1',
              'no_annotations': '1',
              'language': 'en',
            }),
          )
          .timeout(_networkTimeout);
      request.headers.set(HttpHeaders.userAgentHeader, AppMetadata.userAgent);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');

      final response = await request.close().timeout(_networkTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const LocationReverseGeocodeException(
          'Reverse geocoding is temporarily unavailable.',
        );
      }

      final body = await _readResponseBody(response);
      return OpenCageReverseGeocodeParser.parse(body);
    } on TimeoutException {
      throw const LocationReverseGeocodeException(
        'Reverse geocoding timed out.',
      );
    } on SocketException {
      throw const LocationReverseGeocodeException(
        'No network connection. Reverse geocoding needs internet access.',
      );
    } on FormatException {
      throw const LocationReverseGeocodeException(
        'Reverse geocoding returned an unexpected response.',
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
        throw const FormatException('OpenCage response exceeded size cap.');
      }
      bytes.add(chunk);
    }
    return utf8.decode(bytes.takeBytes());
  }
}

class OpenCageReverseGeocodeParser {
  static String? parse(String body) {
    final raw = jsonDecode(body);
    if (raw is! Map<Object?, Object?>) {
      throw const FormatException('Expected an OpenCage response map.');
    }

    final results = raw['results'];
    if (results is! List || results.isEmpty) {
      return null;
    }

    final first = results.first;
    if (first is! Map<Object?, Object?>) {
      return null;
    }

    final formatted = first['formatted']?.toString().trim();
    if (formatted == null || formatted.isEmpty) {
      return null;
    }

    return formatted;
  }
}
