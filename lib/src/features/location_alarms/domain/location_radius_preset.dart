enum LocationRadiusPreset {
  near(500, 'Near', 'Walking or slow traffic'),
  city(1000, 'City', 'Urban traffic and short rides'),
  transit(1500, 'Transit', 'Bus and train friendly');

  const LocationRadiusPreset(this.meters, this.label, this.description);

  final int meters;
  final String label;
  final String description;

  String get summary => '$label ($meters m)';

  static LocationRadiusPreset fromMeters(int? meters) {
    return LocationRadiusPreset.values.firstWhere(
      (preset) => preset.meters == meters,
      orElse: () => LocationRadiusPreset.city,
    );
  }
}
