import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void didUpdateWidget(covariant LocationAlarmMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.centerLatitude != widget.centerLatitude ||
        oldWidget.centerLongitude != widget.centerLongitude ||
        oldWidget.zoom != widget.zoom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        _mapController.move(
          LatLng(widget.centerLatitude, widget.centerLongitude),
          widget.zoom,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selection = widget.selection;

    return NeoPanel(
      padding: EdgeInsets.zero,
      child: ClipRect(
        child: Stack(
          children: [
            SizedBox(
              height: 280,
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: LatLng(
                    widget.centerLatitude,
                    widget.centerLongitude,
                  ),
                  initialZoom: widget.zoom,
                  onTap: (_, point) => widget.onTap(point),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'dev.neoalarm.app',
                  ),
                  if (selection != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(
                            selection.latitude,
                            selection.longitude,
                          ),
                          width: 56,
                          height: 56,
                          child: const Icon(
                            Icons.location_on,
                            size: 44,
                            color: NeoColors.orange,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
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
                    onTap: widget.isCenteringOnCurrentLocation
                        ? null
                        : widget.onCenterOnCurrentLocation,
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
                        child: widget.isCenteringOnCurrentLocation
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
