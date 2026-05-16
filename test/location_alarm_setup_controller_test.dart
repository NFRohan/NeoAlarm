import 'package:flutter_test/flutter_test.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_location_trigger.dart';
import 'package:neoalarm/src/features/location_alarms/application/location_alarm_setup_controller.dart';
import 'package:neoalarm/src/features/location_alarms/data/location_search_repository.dart';
import 'package:neoalarm/src/features/location_alarms/domain/location_radius_preset.dart';
import 'package:neoalarm/src/features/location_alarms/domain/location_search_result.dart';

void main() {
  test('search populates results and selection builds a trigger', () async {
    final controller = LocationAlarmSetupController(
      search: _FakeLocationSearchRepository(
        results: const [
          LocationSearchResult(
            label: 'Banani Station',
            latitude: 23.7937,
            longitude: 90.4066,
          ),
        ],
      ),
    );

    var state = controller.createInitialState();
    state = controller.updateQuery(state, 'Banani Station');
    state = controller.setSearching(state);
    state = await controller.search(state);
    state = controller.selectSearchResult(state, state.searchResults.single);
    state = controller.setRadiusPreset(state, LocationRadiusPreset.transit);

    final trigger = state.draftTrigger;

    expect(state.searchResults, hasLength(1));
    expect(trigger, isNotNull);
    expect(trigger?.label, 'Banani Station');
    expect(trigger?.radiusMeters, 1500);
  });

  test('pinning the map produces a pinned-location draft', () {
    final controller = LocationAlarmSetupController(
      search: _FakeLocationSearchRepository(results: const []),
    );

    var state = controller.createInitialState();
    state = controller.pinLocation(
      state,
      latitude: 23.8103,
      longitude: 90.4125,
    );

    final trigger = state.draftTrigger;

    expect(trigger, isNotNull);
    expect(trigger?.label, 'Pinned location');
    expect(trigger?.latitude, closeTo(23.8103, 0.0001));
    expect(trigger?.longitude, closeTo(90.4125, 0.0001));
  });

  test('editing state can seed from an existing trigger', () {
    final controller = LocationAlarmSetupController(
      search: _FakeLocationSearchRepository(results: const []),
    );

    final state = controller.createInitialState(
      initialTrigger: const AlarmLocationTrigger(
        label: 'Motijheel',
        latitude: 23.7337,
        longitude: 90.4176,
        radiusMeters: 500,
      ),
    );

    expect(state.selection?.label, 'Motijheel');
    expect(state.radiusPreset, LocationRadiusPreset.near);
    expect(state.mapCenterLatitude, closeTo(23.7337, 0.0001));
    expect(state.mapCenterLongitude, closeTo(90.4176, 0.0001));
  });
}

class _FakeLocationSearchRepository implements LocationSearchRepository {
  const _FakeLocationSearchRepository({required this.results});

  final List<LocationSearchResult> results;

  @override
  Future<List<LocationSearchResult>> search(String query) async => results;
}
