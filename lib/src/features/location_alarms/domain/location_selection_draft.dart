import 'package:neoalarm/src/features/location_alarms/domain/location_search_result.dart';

enum LocationSelectionSource { search, pinned }

class LocationSelectionDraft {
  const LocationSelectionDraft({
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.source,
  });

  factory LocationSelectionDraft.fromSearchResult(
    LocationSearchResult result,
  ) {
    return LocationSelectionDraft(
      label: result.label,
      latitude: result.latitude,
      longitude: result.longitude,
      source: LocationSelectionSource.search,
    );
  }

  final String label;
  final double latitude;
  final double longitude;
  final LocationSelectionSource source;

  String get coordinateSummary =>
      '${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)}';

  LocationSelectionDraft copyWith({
    String? label,
    double? latitude,
    double? longitude,
    LocationSelectionSource? source,
  }) {
    return LocationSelectionDraft(
      label: label ?? this.label,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      source: source ?? this.source,
    );
  }
}
