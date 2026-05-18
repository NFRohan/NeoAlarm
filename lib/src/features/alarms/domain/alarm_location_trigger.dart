enum AlarmTriggerKind {
  time('time'),
  location('location');

  const AlarmTriggerKind(this.id);

  final String id;

  static AlarmTriggerKind fromId(String? value) {
    return AlarmTriggerKind.values.firstWhere(
      (kind) => kind.id == value,
      orElse: () => AlarmTriggerKind.time,
    );
  }
}

enum AlarmLocationHealth {
  healthy('healthy', 'Ready'),
  unknown('unknown', 'Readiness unknown'),
  rearmPending('rearm_pending', 'Re-arm pending'),
  noForegroundPermission('no_foreground_permission', 'Needs location access'),
  noBackgroundPermission('no_background_permission', 'Needs background access'),
  locationDisabled('location_disabled', 'Location off'),
  geofenceNotRegistered('geofence_not_registered', 'Geofence not armed'),
  waitingForExit('waiting_for_exit', 'Move outside radius first'),
  playServicesUnavailable(
    'play_services_unavailable',
    'Play services unavailable',
  ),
  batteryRestricted(
    'battery_restricted',
    'Battery restriction may block triggers',
  ),
  lowLocationConfidence(
    'low_location_confidence',
    'Approximate location may be unreliable',
  );

  const AlarmLocationHealth(this.id, this.label);

  final String id;
  final String label;

  String? get repairActionLabel => switch (this) {
    AlarmLocationHealth.unknown => 'Recheck readiness',
    AlarmLocationHealth.rearmPending => null,
    AlarmLocationHealth.noForegroundPermission => 'Grant location access',
    AlarmLocationHealth.noBackgroundPermission => 'Grant background access',
    AlarmLocationHealth.locationDisabled => 'Turn location on',
    AlarmLocationHealth.geofenceNotRegistered => 'Retry arming',
    AlarmLocationHealth.waitingForExit => null,
    AlarmLocationHealth.batteryRestricted => 'Relax battery rules',
    AlarmLocationHealth.playServicesUnavailable => null,
    AlarmLocationHealth.lowLocationConfidence => null,
    AlarmLocationHealth.healthy => null,
  };

  static AlarmLocationHealth fromId(String? value) {
    return AlarmLocationHealth.values.firstWhere(
      (health) => health.id == value,
      orElse: () => AlarmLocationHealth.unknown,
    );
  }
}

class AlarmLocationTrigger {
  const AlarmLocationTrigger({
    required this.label,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    this.health = AlarmLocationHealth.healthy,
    this.geofenceId,
    this.registeredAtUtc,
    this.lastTransitionAtUtc,
  });

  factory AlarmLocationTrigger.fromMap(Map<Object?, Object?> raw) {
    return AlarmLocationTrigger(
      label: (raw['label'] as String?)?.trim().isNotEmpty == true
          ? raw['label']! as String
          : 'Destination',
      latitude: (raw['latitude'] as num).toDouble(),
      longitude: (raw['longitude'] as num).toDouble(),
      radiusMeters: (raw['radiusMeters'] as num).toInt(),
      health: AlarmLocationHealth.fromId(raw['health'] as String?),
      geofenceId: raw['geofenceId'] as String?,
      registeredAtUtc: _readDateTime(raw['registeredAtUtc']),
      lastTransitionAtUtc: _readDateTime(raw['lastTransitionAtUtc']),
    );
  }

  final String label;
  final double latitude;
  final double longitude;
  final int radiusMeters;
  final AlarmLocationHealth health;
  final String? geofenceId;
  final DateTime? registeredAtUtc;
  final DateTime? lastTransitionAtUtc;

  bool get isHealthy => health == AlarmLocationHealth.healthy;

  String? get repairActionLabel => health.repairActionLabel;

  String get radiusSummary => '$radiusMeters m';

  AlarmLocationTrigger copyWith({
    String? label,
    double? latitude,
    double? longitude,
    int? radiusMeters,
    AlarmLocationHealth? health,
    String? geofenceId,
    DateTime? registeredAtUtc,
    DateTime? lastTransitionAtUtc,
    bool clearGeofenceId = false,
    bool clearRegisteredAtUtc = false,
    bool clearLastTransitionAtUtc = false,
  }) {
    return AlarmLocationTrigger(
      label: label ?? this.label,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      radiusMeters: radiusMeters ?? this.radiusMeters,
      health: health ?? this.health,
      geofenceId: clearGeofenceId ? null : geofenceId ?? this.geofenceId,
      registeredAtUtc: clearRegisteredAtUtc
          ? null
          : registeredAtUtc ?? this.registeredAtUtc,
      lastTransitionAtUtc: clearLastTransitionAtUtc
          ? null
          : lastTransitionAtUtc ?? this.lastTransitionAtUtc,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'label': label,
      'latitude': latitude,
      'longitude': longitude,
      'radiusMeters': radiusMeters,
      'health': health.id,
      'geofenceId': geofenceId,
      'registeredAtUtc': registeredAtUtc?.toIso8601String(),
      'lastTransitionAtUtc': lastTransitionAtUtc?.toIso8601String(),
    };
  }

  static DateTime? _readDateTime(Object? value) {
    if (value is! String || value.isEmpty) {
      return null;
    }

    return DateTime.tryParse(value)?.toUtc();
  }
}
