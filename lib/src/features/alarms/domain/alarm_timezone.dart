String formatTimezoneDisplayName(String timezoneId) {
  final normalized = timezoneId.replaceAll('_', ' ');
  final segments = normalized.split('/');
  if (segments.isEmpty) {
    return normalized;
  }

  final preferred = segments.lastWhere(
    (segment) => segment.isNotEmpty,
    orElse: () => normalized,
  );
  return preferred.isEmpty ? normalized : preferred;
}

String formatTimezoneSummary(String timezoneId) {
  final displayName = formatTimezoneDisplayName(timezoneId);
  if (displayName.toUpperCase() == 'UTC' ||
      displayName.toUpperCase() == 'GMT') {
    return displayName.toUpperCase();
  }
  return '$displayName time';
}
