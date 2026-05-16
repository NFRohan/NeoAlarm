class CurrentLocationSnapshot {
  const CurrentLocationSnapshot({
    required this.latitude,
    required this.longitude,
    required this.accuracyMeters,
  });

  factory CurrentLocationSnapshot.fromMap(Map<Object?, Object?> raw) {
    return CurrentLocationSnapshot(
      latitude: (raw['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (raw['longitude'] as num?)?.toDouble() ?? 0,
      accuracyMeters: (raw['accuracyMeters'] as num?)?.toDouble() ?? 0,
    );
  }

  final double latitude;
  final double longitude;
  final double accuracyMeters;
}
