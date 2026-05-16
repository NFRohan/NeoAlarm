import 'package:neoalarm/src/features/alarms/domain/alarm_location_trigger.dart';
import 'package:neoalarm/src/features/location_alarms/domain/location_radius_preset.dart';
import 'package:neoalarm/src/features/location_alarms/domain/location_search_result.dart';
import 'package:neoalarm/src/features/location_alarms/domain/location_selection_draft.dart';

class LocationAlarmSetupState {
  const LocationAlarmSetupState({
    required this.query,
    required this.isSearching,
    required this.searchResults,
    required this.radiusPreset,
    required this.mapCenterLatitude,
    required this.mapCenterLongitude,
    required this.mapZoom,
    this.searchError,
    this.selection,
  });

  factory LocationAlarmSetupState.initial({
    AlarmLocationTrigger? initialTrigger,
  }) {
    if (initialTrigger != null) {
      final normalizedLabel = initialTrigger.label.trim().toLowerCase();
      final seededQuery =
          normalizedLabel == 'pinned location' ||
              normalizedLabel == 'destination'
          ? ''
          : initialTrigger.label;
      return LocationAlarmSetupState(
        query: seededQuery,
        isSearching: false,
        searchResults: const [],
        searchError: null,
        selection: LocationSelectionDraft(
          label: initialTrigger.label,
          latitude: initialTrigger.latitude,
          longitude: initialTrigger.longitude,
          source: LocationSelectionSource.search,
        ),
        radiusPreset: LocationRadiusPreset.fromMeters(
          initialTrigger.radiusMeters,
        ),
        mapCenterLatitude: initialTrigger.latitude,
        mapCenterLongitude: initialTrigger.longitude,
        mapZoom: 13.5,
      );
    }

    return const LocationAlarmSetupState(
      query: '',
      isSearching: false,
      searchResults: [],
      searchError: null,
      selection: null,
      radiusPreset: LocationRadiusPreset.city,
      mapCenterLatitude: 20,
      mapCenterLongitude: 0,
      mapZoom: 2.4,
    );
  }

  final String query;
  final bool isSearching;
  final List<LocationSearchResult> searchResults;
  final String? searchError;
  final LocationSelectionDraft? selection;
  final LocationRadiusPreset radiusPreset;
  final double mapCenterLatitude;
  final double mapCenterLongitude;
  final double mapZoom;

  bool get hasSelection => selection != null;

  AlarmLocationTrigger? get draftTrigger {
    final selected = selection;
    if (selected == null) {
      return null;
    }

    return AlarmLocationTrigger(
      label: selected.label,
      latitude: selected.latitude,
      longitude: selected.longitude,
      radiusMeters: radiusPreset.meters,
    );
  }

  LocationAlarmSetupState copyWith({
    String? query,
    bool? isSearching,
    List<LocationSearchResult>? searchResults,
    String? searchError,
    LocationSelectionDraft? selection,
    LocationRadiusPreset? radiusPreset,
    double? mapCenterLatitude,
    double? mapCenterLongitude,
    double? mapZoom,
    bool clearSearchError = false,
    bool clearSelection = false,
  }) {
    return LocationAlarmSetupState(
      query: query ?? this.query,
      isSearching: isSearching ?? this.isSearching,
      searchResults: searchResults ?? this.searchResults,
      searchError: clearSearchError ? null : searchError ?? this.searchError,
      selection: clearSelection ? null : selection ?? this.selection,
      radiusPreset: radiusPreset ?? this.radiusPreset,
      mapCenterLatitude: mapCenterLatitude ?? this.mapCenterLatitude,
      mapCenterLongitude: mapCenterLongitude ?? this.mapCenterLongitude,
      mapZoom: mapZoom ?? this.mapZoom,
    );
  }
}
