import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neoalarm/src/features/location_alarms/data/opencage_reverse_geocode_repository.dart';
import 'package:neoalarm/src/features/settings/application/location_provider_settings_controller.dart';

final locationReverseGeocodeRepositoryProvider =
    Provider<LocationReverseGeocodeRepository>((ref) {
      final apiKey = ref
          .watch(locationProviderSettingsControllerProvider)
          .asData
          ?.value
          .openCageApiKey;
      return buildLocationReverseGeocodeRepository(openCageApiKey: apiKey);
    });

abstract class LocationReverseGeocodeRepository {
  Future<String?> reverseGeocode({
    required double latitude,
    required double longitude,
  });
}

LocationReverseGeocodeRepository buildLocationReverseGeocodeRepository({
  String? openCageApiKey,
}) {
  final apiKey = openCageApiKey?.trim() ?? '';
  if (apiKey.isEmpty) {
    return const NoopLocationReverseGeocodeRepository();
  }
  return OpenCageReverseGeocodeRepository(apiKey: apiKey);
}

class NoopLocationReverseGeocodeRepository
    implements LocationReverseGeocodeRepository {
  const NoopLocationReverseGeocodeRepository();

  @override
  Future<String?> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    return null;
  }
}

class LocationReverseGeocodeException implements Exception {
  const LocationReverseGeocodeException(this.message);

  final String message;

  @override
  String toString() => message;
}
