import 'package:neoalarm/src/features/alarms/domain/alarm_location_trigger.dart';
import 'package:neoalarm/src/features/location_alarms/application/location_alarm_setup_state.dart';
import 'package:neoalarm/src/features/location_alarms/data/location_search_repository.dart';
import 'package:neoalarm/src/features/location_alarms/domain/location_radius_preset.dart';
import 'package:neoalarm/src/features/location_alarms/domain/location_search_result.dart';
import 'package:neoalarm/src/features/location_alarms/domain/location_selection_draft.dart';

class LocationAlarmSetupController {
  const LocationAlarmSetupController({required LocationSearchRepository search})
    : _search = search;

  final LocationSearchRepository _search;

  LocationAlarmSetupState createInitialState({
    AlarmLocationTrigger? initialTrigger,
  }) {
    return LocationAlarmSetupState.initial(initialTrigger: initialTrigger);
  }

  LocationAlarmSetupState updateQuery(
    LocationAlarmSetupState state,
    String query,
  ) {
    return state.copyWith(query: query, clearSearchError: true);
  }

  LocationAlarmSetupState setSearching(LocationAlarmSetupState state) {
    return state.copyWith(
      isSearching: true,
      clearSearchError: true,
      searchResults: const [],
    );
  }

  Future<LocationAlarmSetupState> search(LocationAlarmSetupState state) async {
    final trimmedQuery = state.query.trim();
    if (trimmedQuery.isEmpty) {
      return state.copyWith(
        isSearching: false,
        searchResults: const [],
        searchError: 'Enter a place, station, or stop first.',
      );
    }

    try {
      final results = await _search.search(trimmedQuery);
      return state.copyWith(
        isSearching: false,
        searchResults: results,
        searchError: results.isEmpty ? 'No places matched that search.' : null,
      );
    } on LocationSearchException catch (error) {
      return state.copyWith(
        isSearching: false,
        searchResults: const [],
        searchError: error.message,
      );
    } catch (_) {
      return state.copyWith(
        isSearching: false,
        searchResults: const [],
        searchError: 'Location search failed. Please try again.',
      );
    }
  }

  LocationAlarmSetupState selectSearchResult(
    LocationAlarmSetupState state,
    LocationSearchResult result,
  ) {
    final selection = LocationSelectionDraft.fromSearchResult(result);
    return state.copyWith(
      selection: selection,
      mapCenterLatitude: selection.latitude,
      mapCenterLongitude: selection.longitude,
      mapZoom: 13.5,
      clearSearchError: true,
    );
  }

  LocationAlarmSetupState pinLocation(
    LocationAlarmSetupState state, {
    required double latitude,
    required double longitude,
  }) {
    return state.copyWith(
      selection: LocationSelectionDraft(
        label: 'Pinned location',
        latitude: latitude,
        longitude: longitude,
        source: LocationSelectionSource.pinned,
      ),
      mapCenterLatitude: latitude,
      mapCenterLongitude: longitude,
      mapZoom: 13.5,
      clearSearchError: true,
    );
  }

  LocationAlarmSetupState centerMap(
    LocationAlarmSetupState state, {
    required double latitude,
    required double longitude,
  }) {
    return state.copyWith(
      mapCenterLatitude: latitude,
      mapCenterLongitude: longitude,
      mapZoom: 13.5,
      clearSearchError: true,
    );
  }

  LocationAlarmSetupState setRadiusPreset(
    LocationAlarmSetupState state,
    LocationRadiusPreset preset,
  ) {
    return state.copyWith(radiusPreset: preset);
  }
}
