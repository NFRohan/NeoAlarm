import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:neoalarm/src/core/theme/app_theme.dart';
import 'package:neoalarm/src/core/ui/neo_brutal_widgets.dart';
import 'package:neoalarm/src/features/location_alarms/domain/location_selection_draft.dart';

class LocationAlarmMap extends StatefulWidget {
  const LocationAlarmMap({
    required this.centerLatitude,
    required this.centerLongitude,
    required this.zoom,
    required this.onTap,
    required this.onCenterOnCurrentLocation,
    required this.isCenteringOnCurrentLocation,
    this.selection,
    super.key,
  });

  static const openFreeMapStyleUrl =
      'https://tiles.openfreemap.org/styles/liberty';

  static final mapGestureRecognizers = <Factory<OneSequenceGestureRecognizer>>{
    Factory<OneSequenceGestureRecognizer>(() => EagerGestureRecognizer()),
  };

  final double centerLatitude;
  final double centerLongitude;
  final double zoom;
  final ValueChanged<LatLng> onTap;
  final VoidCallback onCenterOnCurrentLocation;
  final bool isCenteringOnCurrentLocation;
  final LocationSelectionDraft? selection;

  @override
  State<LocationAlarmMap> createState() => _LocationAlarmMapState();
}

class _LocationAlarmMapState extends State<LocationAlarmMap> {
  MapLibreMapController? _mapController;
  bool _styleLoaded = false;

  @override
  void didUpdateWidget(covariant LocationAlarmMap oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (_mapController != null &&
        (oldWidget.centerLatitude != widget.centerLatitude ||
            oldWidget.centerLongitude != widget.centerLongitude ||
            oldWidget.zoom != widget.zoom)) {
      _moveCamera();
    }

    if (_styleLoaded && oldWidget.selection != widget.selection) {
      _syncSelectionMarker();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _MapShell(
      selection: widget.selection,
      isCenteringOnCurrentLocation: widget.isCenteringOnCurrentLocation,
      onCenterOnCurrentLocation: widget.onCenterOnCurrentLocation,
      child: MapLibreMap(
        styleString: LocationAlarmMap.openFreeMapStyleUrl,
        initialCameraPosition: CameraPosition(
          target: LatLng(widget.centerLatitude, widget.centerLongitude),
          zoom: widget.zoom,
        ),
        gestureRecognizers: LocationAlarmMap.mapGestureRecognizers,
        onMapCreated: _handleMapCreated,
        onStyleLoadedCallback: _handleStyleLoaded,
        onMapClick: (_, latLng) => widget.onTap(latLng),
        compassEnabled: false,
        rotateGesturesEnabled: false,
        tiltGesturesEnabled: false,
        myLocationEnabled: false,
      ),
    );
  }

  void _handleMapCreated(MapLibreMapController controller) {
    _mapController = controller;
  }

  Future<void> _handleStyleLoaded() async {
    _styleLoaded = true;
    await _moveCamera();
    await _syncSelectionMarker();
  }

  Future<void> _moveCamera() async {
    final controller = _mapController;
    if (controller == null) {
      return;
    }

    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(widget.centerLatitude, widget.centerLongitude),
          zoom: widget.zoom,
        ),
      ),
    );
  }

  Future<void> _syncSelectionMarker() async {
    final controller = _mapController;
    if (controller == null || !_styleLoaded) {
      return;
    }

    await controller.clearCircles();

    final selection = widget.selection;
    if (selection == null) {
      return;
    }

    await controller.addCircle(
      CircleOptions(
        geometry: LatLng(selection.latitude, selection.longitude),
        circleColor: '#F59E0B',
        circleRadius: 8,
        circleOpacity: 0.95,
        circleStrokeColor: '#111111',
        circleStrokeWidth: 3,
      ),
    );
  }
}

class _MapShell extends StatelessWidget {
  const _MapShell({
    required this.child,
    required this.selection,
    required this.isCenteringOnCurrentLocation,
    required this.onCenterOnCurrentLocation,
  });

  final Widget child;
  final LocationSelectionDraft? selection;
  final bool isCenteringOnCurrentLocation;
  final VoidCallback onCenterOnCurrentLocation;

  @override
  Widget build(BuildContext context) {
    return NeoPanel(
      padding: EdgeInsets.zero,
      child: ClipRect(
        child: Stack(
          children: [
            SizedBox(height: 280, child: child),
            Positioned(
              left: 12,
              right: 12,
              top: 12,
              child: IgnorePointer(
                child: NeoPanel(
                  color: NeoColors.panel.withValues(alpha: 0.94),
                  borderWidth: 2,
                  shadowOffset: const Offset(2, 2),
                  child: Text(
                    selection == null
                        ? 'Search for a place or tap anywhere on the map to drop a pin.'
                        : 'Tap the map again if you want to adjust the destination pin.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: NeoColors.subtext),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 12,
              bottom: 12,
              child: Tooltip(
                message: 'Center on my location',
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: const Key('location_alarm_map_center_button'),
                    onTap: isCenteringOnCurrentLocation
                        ? null
                        : onCenterOnCurrentLocation,
                    customBorder: const CircleBorder(),
                    child: Ink(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: NeoColors.panel.withValues(alpha: 0.98),
                        border: Border.all(color: NeoColors.ink, width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black26,
                            offset: Offset(2, 2),
                            blurRadius: 0,
                          ),
                        ],
                      ),
                      child: Center(
                        child: isCenteringOnCurrentLocation
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation(
                                    NeoColors.accentInk,
                                  ),
                                ),
                              )
                            : const Icon(
                                Icons.my_location,
                                size: 22,
                                color: NeoColors.cyan,
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
