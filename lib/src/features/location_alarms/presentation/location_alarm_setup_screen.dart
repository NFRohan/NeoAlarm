import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neoalarm/src/core/theme/app_theme.dart';
import 'package:neoalarm/src/core/ui/neo_brutal_widgets.dart';
import 'package:neoalarm/src/features/alarms/application/alarm_list_controller.dart';
import 'package:neoalarm/src/features/alarms/domain/alarm_location_trigger.dart';
import 'package:neoalarm/src/features/location_alarms/application/location_alarm_setup_controller.dart';
import 'package:neoalarm/src/features/location_alarms/application/location_alarm_setup_state.dart';
import 'package:neoalarm/src/features/location_alarms/data/location_search_repository.dart';
import 'package:neoalarm/src/features/location_alarms/domain/current_location_snapshot.dart';
import 'package:neoalarm/src/features/location_alarms/domain/location_alarm_setup_diagnostics.dart';
import 'package:neoalarm/src/features/location_alarms/domain/location_radius_preset.dart';
import 'package:neoalarm/src/features/location_alarms/domain/location_search_result.dart';
import 'package:neoalarm/src/features/location_alarms/presentation/widgets/location_alarm_map.dart';

class LocationAlarmSetupScreen extends ConsumerStatefulWidget {
  const LocationAlarmSetupScreen({this.initialTrigger, super.key});

  final AlarmLocationTrigger? initialTrigger;

  static Future<AlarmLocationTrigger?> show(
    BuildContext context, {
    AlarmLocationTrigger? initialTrigger,
  }) {
    return Navigator.of(context).push<AlarmLocationTrigger>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) =>
            LocationAlarmSetupScreen(initialTrigger: initialTrigger),
      ),
    );
  }

  @override
  ConsumerState<LocationAlarmSetupScreen> createState() =>
      _LocationAlarmSetupScreenState();
}

class _LocationAlarmSetupScreenState
    extends ConsumerState<LocationAlarmSetupScreen>
    with WidgetsBindingObserver {
  late final TextEditingController _queryController;
  late final LocationAlarmSetupController _controller;
  late LocationAlarmSetupState _state;
  LocationAlarmSetupDiagnostics? _diagnostics;
  bool _currentLocationInFlight = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = LocationAlarmSetupController(
      search: ref.read(locationSearchRepositoryProvider),
    );
    _state = _controller.createInitialState(
      initialTrigger: widget.initialTrigger,
    );
    _queryController = TextEditingController(text: _state.query);
    if (_state.draftTrigger != null) {
      unawaited(_refreshDiagnostics());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _queryController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(alarmEngineStatusProvider);
      if (_state.draftTrigger != null) {
        unawaited(_refreshDiagnostics());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = _state.selection;
    final diagnostics = _diagnostics;
    final showInsideRadiusWarning = diagnostics?.alreadyInsideRadius == true;

    return Scaffold(
      backgroundColor: NeoColors.paper,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  NeoSquareIconButton(
                    icon: Icons.close,
                    size: 42,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LOCATION ALARM',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Search a destination or drop a pin, then choose how early NeoAlarm should trigger.',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                children: [
                  _SearchPanel(
                    controller: _queryController,
                    isSearching: _state.isSearching,
                    onChanged: (value) {
                      setState(() {
                        _state = _controller.updateQuery(_state, value);
                      });
                    },
                    onSubmitted: (_) => _runSearch(),
                    onSearch: _runSearch,
                  ),
                  const SizedBox(height: 16),
                  if (_state.searchError != null) ...[
                    NeoPanel(
                      color: NeoColors.warm,
                      child: Text(
                        _state.searchError!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: NeoColors.warningText,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_state.searchResults.isNotEmpty) ...[
                    _SearchResultsPanel(
                      results: _state.searchResults,
                      selectedLabel: selected?.label,
                      onSelected: (result) {
                        setState(() {
                          _state = _controller.selectSearchResult(
                            _state,
                            result,
                          );
                        });
                        unawaited(_refreshDiagnostics());
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                  Text('MAP', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  LocationAlarmMap(
                    centerLatitude: _state.mapCenterLatitude,
                    centerLongitude: _state.mapCenterLongitude,
                    zoom: _state.mapZoom,
                    selection: selected,
                    isCenteringOnCurrentLocation: _currentLocationInFlight,
                    onTap: (point) {
                      setState(() {
                        _state = _controller.pinLocation(
                          _state,
                          latitude: point.latitude,
                          longitude: point.longitude,
                        );
                      });
                      unawaited(_refreshDiagnostics());
                    },
                    onCenterOnCurrentLocation: _centerMapOnCurrentLocation,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Map data | OpenStreetMap contributors',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: NeoColors.subtext,
                    ),
                  ),
                  const SizedBox(height: 12),
                  NeoPanel(
                    color: selected == null ? NeoColors.panel : NeoColors.cyan,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selected == null
                              ? 'NO DESTINATION SELECTED'
                              : 'DESTINATION READY',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          selected?.label ??
                              'Search for a place first, or tap the map to drop a pin manually.',
                          style: theme.textTheme.bodyMedium,
                        ),
                        if (selected != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            selected.coordinateSummary,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: NeoColors.subtext,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (showInsideRadiusWarning) ...[
                    const SizedBox(height: 12),
                    NeoPanel(
                      color: NeoColors.orange,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            diagnostics!.headline,
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            diagnostics.detail,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: NeoColors.warningText,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Text('TRIGGER RADIUS', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(
                    'Larger radii are safer because Android location alarms can arrive late, especially on buses and trains.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 10),
                  _RadiusPresetGrid(
                    selectedPreset: _state.radiusPreset,
                    onSelected: (preset) {
                      setState(() {
                        _state = _controller.setRadiusPreset(_state, preset);
                      });
                      unawaited(_refreshDiagnostics());
                    },
                  ),
                  const SizedBox(height: 18),
                  NeoPanel(
                    color: NeoColors.orange,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RELIABILITY NOTES',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Location alarms need GPS or network location. They can be late, and they may not trigger underground until signal returns.',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
              child: Row(
                children: [
                  Expanded(
                    child: NeoActionButton(
                      label: 'Cancel',
                      backgroundColor: NeoColors.panel,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: NeoActionButton(
                      label: 'Use destination',
                      backgroundColor: NeoColors.primary,
                      onPressed: _state.draftTrigger == null
                          ? null
                          : _handlePrimaryAction,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runSearch() async {
    setState(() {
      _state = _controller.setSearching(_state);
    });

    final nextState = await _controller.search(_state);
    if (!mounted) {
      return;
    }

    setState(() {
      _state = nextState;
    });
  }

  Future<void> _refreshDiagnostics() async {
    final draftTrigger = _state.draftTrigger;
    if (draftTrigger == null) {
      if (!mounted) {
        return;
      }
      setState(() {
        _diagnostics = null;
      });
      return;
    }

    final diagnostics = await ref
        .read(alarmRepositoryProvider)
        .evaluateLocationTrigger(draftTrigger);
    if (!mounted) {
      return;
    }

    setState(() {
      _diagnostics = diagnostics;
    });
  }

  Future<void> _centerMapOnCurrentLocation() async {
    setState(() {
      _currentLocationInFlight = true;
    });

    try {
      final snapshot = await ref
          .read(alarmRepositoryProvider)
          .getCurrentLocationSnapshot();
      if (!mounted) {
        return;
      }

      if (snapshot == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Current location is unavailable right now. Check location access and services, then try again.',
            ),
          ),
        );
        return;
      }

      _applyCurrentLocationCenter(snapshot);
    } finally {
      if (mounted) {
        setState(() {
          _currentLocationInFlight = false;
        });
      }
    }
  }

  void _applyCurrentLocationCenter(CurrentLocationSnapshot snapshot) {
    setState(() {
      _state = _controller.centerMap(
        _state,
        latitude: snapshot.latitude,
        longitude: snapshot.longitude,
      );
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Map centered on your current location. Tap to drop a pin if you want to use it as the destination.',
        ),
      ),
    );
  }

  Future<void> _handlePrimaryAction() async {
    if (_state.draftTrigger == null) {
      return;
    }

    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(_state.draftTrigger);
  }
}

class _SearchPanel extends StatelessWidget {
  const _SearchPanel({
    required this.controller,
    required this.isSearching,
    required this.onChanged,
    required this.onSubmitted,
    required this.onSearch,
  });

  final TextEditingController controller;
  final bool isSearching;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    return NeoPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SEARCH DESTINATION',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  textInputAction: TextInputAction.search,
                  onChanged: onChanged,
                  onSubmitted: onSubmitted,
                  decoration: const InputDecoration(
                    hintText: 'Station, stop, landmark, or area',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              NeoSquareIconButton(
                icon: isSearching ? Icons.hourglass_top : Icons.search,
                backgroundColor: NeoColors.cyan,
                foregroundColor: NeoColors.accentInk,
                size: 44,
                onPressed: isSearching ? null : onSearch,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SearchResultsPanel extends StatelessWidget {
  const _SearchResultsPanel({
    required this.results,
    required this.selectedLabel,
    required this.onSelected,
  });

  final List<LocationSearchResult> results;
  final String? selectedLabel;
  final ValueChanged<LocationSearchResult> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return NeoPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SEARCH RESULTS', style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),
          for (final result in results) ...[
            InkWell(
              onTap: () => onSelected(result),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: NeoColors.ink.withValues(alpha: 0.15),
                    ),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.only(top: 4),
                      decoration: BoxDecoration(
                        color: selectedLabel == result.label
                            ? NeoColors.success
                            : NeoColors.cyan,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        result.label,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RadiusPresetGrid extends StatelessWidget {
  const _RadiusPresetGrid({
    required this.selectedPreset,
    required this.onSelected,
  });

  final LocationRadiusPreset selectedPreset;
  final ValueChanged<LocationRadiusPreset> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final preset in LocationRadiusPreset.values) ...[
          _RadiusPresetTile(
            preset: preset,
            selected: preset == selectedPreset,
            onTap: () => onSelected(preset),
          ),
          if (preset != LocationRadiusPreset.values.last)
            const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _RadiusPresetTile extends StatelessWidget {
  const _RadiusPresetTile({
    required this.preset,
    required this.selected,
    required this.onTap,
  });

  final LocationRadiusPreset preset;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: NeoPanel(
        color: selected ? NeoColors.primary : NeoColors.panel,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preset.summary.toUpperCase(),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    preset.description,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: NeoColors.subtext),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? NeoColors.accentInk : NeoColors.ink,
            ),
          ],
        ),
      ),
    );
  }
}
