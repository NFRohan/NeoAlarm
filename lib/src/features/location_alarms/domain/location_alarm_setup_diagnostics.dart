import 'package:neoalarm/src/features/alarms/domain/alarm_location_trigger.dart';

class LocationAlarmSetupDiagnostics {
  const LocationAlarmSetupDiagnostics({
    required this.health,
    required this.alreadyInsideRadius,
    this.distanceMeters,
  });

  factory LocationAlarmSetupDiagnostics.fromMap(Map<Object?, Object?> raw) {
    return LocationAlarmSetupDiagnostics(
      health: AlarmLocationHealth.fromId(raw['health'] as String?),
      alreadyInsideRadius: raw['alreadyInsideRadius'] as bool? ?? false,
      distanceMeters: (raw['distanceMeters'] as num?)?.toInt(),
    );
  }

  final AlarmLocationHealth health;
  final bool alreadyInsideRadius;
  final int? distanceMeters;

  bool get isBlocking =>
      health != AlarmLocationHealth.healthy &&
      health != AlarmLocationHealth.batteryRestricted &&
      health != AlarmLocationHealth.lowLocationConfidence;

  String get headline {
    if (alreadyInsideRadius) {
      return 'ALREADY INSIDE RADIUS';
    }
    return health.label.toUpperCase();
  }

  String get detail {
    if (alreadyInsideRadius) {
      final distance = distanceMeters;
      if (distance == null) {
        return 'This phone already appears to be inside the selected radius. We should warn instead of assuming ENTER will fire later.';
      }

      return 'This phone already appears to be inside the selected radius, about $distance m from the target point.';
    }

    return switch (health) {
      AlarmLocationHealth.healthy =>
        'Foreground checks look healthy for this destination.',
      AlarmLocationHealth.unknown =>
        'NeoAlarm could not verify this destination alarm state. Recheck readiness before trusting it.',
      AlarmLocationHealth.rearmPending =>
        'NeoAlarm is waiting to retry geofence arming after a transient system failure.',
      AlarmLocationHealth.noForegroundPermission =>
        'Foreground location access is still missing.',
      AlarmLocationHealth.noBackgroundPermission =>
        'Background location is still missing, so Android cannot trigger this destination alarm reliably.',
      AlarmLocationHealth.locationDisabled =>
        'Android location services are off right now.',
      AlarmLocationHealth.geofenceNotRegistered =>
        'The destination could not be armed with Android geofencing yet.',
      AlarmLocationHealth.waitingForExit =>
        'This destination is armed, but the phone needs to move outside the radius before a later re-entry can trigger it.',
      AlarmLocationHealth.playServicesUnavailable =>
        'Google Play services are unavailable, so geofencing cannot arm.',
      AlarmLocationHealth.batteryRestricted =>
        'The destination can arm, but battery restrictions may still delay callbacks.',
      AlarmLocationHealth.lowLocationConfidence =>
        'Approximate location may make this destination less reliable.',
    };
  }
}
