import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/settings/app_preferences.dart';

final appPreferencesStoreProvider = Provider<AppPreferencesStore>(
  (ref) => AppPreferencesStore(),
);

final appPreferencesProvider = FutureProvider<AppPreferencesState>(
  (ref) => ref.watch(appPreferencesStoreProvider).load(),
);

final appPreferencesCommandsProvider =
    Provider<AppPreferencesCommands>(AppPreferencesCommands.new);

final packageInfoProvider = FutureProvider<PackageInfo>(
  (ref) => PackageInfo.fromPlatform(),
);

class AppPreferencesCommands {
  AppPreferencesCommands(this.ref);

  final Ref ref;

  Future<void> setNotificationsEnabled(bool value) async {
    await ref.read(appPreferencesStoreProvider).setNotificationsEnabled(value);
    ref.invalidate(appPreferencesProvider);
  }

  Future<void> setReminderNotificationsEnabled(bool value) async {
    await ref
        .read(appPreferencesStoreProvider)
        .setReminderNotificationsEnabled(value);
    ref.invalidate(appPreferencesProvider);
  }

  Future<void> setFocusNotificationsEnabled(bool value) async {
    await ref
        .read(appPreferencesStoreProvider)
        .setFocusNotificationsEnabled(value);
    ref.invalidate(appPreferencesProvider);
  }

  Future<void> setUiDensity(UiDensityPreference value) async {
    await ref.read(appPreferencesStoreProvider).setUiDensity(value);
    ref.invalidate(appPreferencesProvider);
  }

  Future<void> setWeekStartsMonday(bool value) async {
    await ref.read(appPreferencesStoreProvider).setWeekStartsMonday(value);
    ref.invalidate(appPreferencesProvider);
  }
}
