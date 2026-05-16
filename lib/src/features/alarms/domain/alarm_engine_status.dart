class AlarmEngineStatus {
  const AlarmEngineStatus({
    required this.canScheduleExactAlarms,
    required this.notificationsEnabled,
    required this.batteryOptimizationIgnored,
    required this.hasCamera,
    required this.cameraPermissionGranted,
    required this.hasStepSensor,
    required this.activityRecognitionGranted,
    required this.timezoneId,
    this.locationServicesEnabled = false,
    this.foregroundLocationGranted = false,
    this.backgroundLocationGranted = false,
  });

  factory AlarmEngineStatus.fromMap(Map<Object?, Object?> raw) {
    return AlarmEngineStatus(
      canScheduleExactAlarms: raw['canScheduleExactAlarms']! as bool,
      notificationsEnabled: raw['notificationsEnabled']! as bool,
      batteryOptimizationIgnored: raw['batteryOptimizationIgnored']! as bool,
      hasCamera: raw['hasCamera']! as bool,
      cameraPermissionGranted: raw['cameraPermissionGranted']! as bool,
      hasStepSensor: raw['hasStepSensor']! as bool,
      activityRecognitionGranted: raw['activityRecognitionGranted']! as bool,
      timezoneId: raw['timezoneId']! as String,
      locationServicesEnabled: raw['locationServicesEnabled'] as bool? ?? false,
      foregroundLocationGranted: raw['foregroundLocationGranted'] as bool? ?? false,
      backgroundLocationGranted: raw['backgroundLocationGranted'] as bool? ?? false,
    );
  }

  final bool canScheduleExactAlarms;
  final bool notificationsEnabled;
  final bool batteryOptimizationIgnored;
  final bool hasCamera;
  final bool cameraPermissionGranted;
  final bool hasStepSensor;
  final bool activityRecognitionGranted;
  final String timezoneId;
  final bool locationServicesEnabled;
  final bool foregroundLocationGranted;
  final bool backgroundLocationGranted;

  bool get cameraReady => hasCamera && cameraPermissionGranted;

  bool get stepsMissionReady => hasStepSensor && activityRecognitionGranted;

  bool get locationForegroundReady =>
      locationServicesEnabled && foregroundLocationGranted;

  bool get locationBackgroundReady =>
      locationForegroundReady && backgroundLocationGranted;
}
