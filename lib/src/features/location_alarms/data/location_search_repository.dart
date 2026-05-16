import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neoalarm/src/features/location_alarms/data/nominatim_location_search_repository.dart';
import 'package:neoalarm/src/features/location_alarms/domain/location_search_result.dart';

final locationSearchRepositoryProvider = Provider<LocationSearchRepository>(
  (ref) => const NominatimLocationSearchRepository(),
);

abstract class LocationSearchRepository {
  Future<List<LocationSearchResult>> search(String query);
}

class LocationSearchException implements Exception {
  const LocationSearchException(this.message);

  final String message;

  @override
  String toString() => message;
}
