import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:neoalarm/src/features/app_startup/application/app_startup_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

final locationProviderSettingsControllerProvider = AsyncNotifierProvider<
  LocationProviderSettingsController,
  LocationProviderSettings
>(LocationProviderSettingsController.new);

class LocationProviderSettingsController
    extends AsyncNotifier<LocationProviderSettings> {
  static const _openCageApiKeyPreferenceKey =
      'settings.location_provider.opencage_api_key';

  @override
  Future<LocationProviderSettings> build() async {
    final startupContext = await ref.watch(appStartupContextProvider.future);
    if (startupContext.isDirectBootMode) {
      return const LocationProviderSettings();
    }

    try {
      final preferences = await SharedPreferences.getInstance();
      return LocationProviderSettings(
        openCageApiKey:
            preferences.getString(_openCageApiKeyPreferenceKey) ?? '',
      );
    } catch (_) {
      return const LocationProviderSettings();
    }
  }

  Future<void> setOpenCageApiKey(String apiKey) async {
    final trimmedKey = apiKey.trim();
    state = AsyncData(LocationProviderSettings(openCageApiKey: trimmedKey));

    final startupContext = await ref.read(appStartupContextProvider.future);
    if (startupContext.isDirectBootMode) {
      return;
    }

    final preferences = await SharedPreferences.getInstance();
    if (trimmedKey.isEmpty) {
      await preferences.remove(_openCageApiKeyPreferenceKey);
      return;
    }
    await preferences.setString(_openCageApiKeyPreferenceKey, trimmedKey);
  }

  Future<void> clearOpenCageApiKey() async {
    state = const AsyncData(LocationProviderSettings());

    final startupContext = await ref.read(appStartupContextProvider.future);
    if (startupContext.isDirectBootMode) {
      return;
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_openCageApiKeyPreferenceKey);
  }
}

class LocationProviderSettings {
  const LocationProviderSettings({this.openCageApiKey = ''});

  final String openCageApiKey;

  bool get hasOpenCageApiKey => openCageApiKey.trim().isNotEmpty;
}
