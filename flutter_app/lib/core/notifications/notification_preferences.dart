import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferences {
  const NotificationPreferences({
    this.remindersEnabled = true,
    this.focusEnabled = true,
  });

  final bool remindersEnabled;
  final bool focusEnabled;

  NotificationPreferences copyWith({
    bool? remindersEnabled,
    bool? focusEnabled,
  }) =>
      NotificationPreferences(
        remindersEnabled: remindersEnabled ?? this.remindersEnabled,
        focusEnabled: focusEnabled ?? this.focusEnabled,
      );
}

class NotificationPreferencesStore {
  const NotificationPreferencesStore();

  static const remindersKey =
      'lifetrace.execute.notifications.reminders.v1';
  static const focusKey = 'lifetrace.execute.notifications.focus.v1';

  Future<NotificationPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    return NotificationPreferences(
      remindersEnabled: prefs.getBool(remindersKey) ?? true,
      focusEnabled: prefs.getBool(focusKey) ?? true,
    );
  }

  Future<void> save(NotificationPreferences value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(remindersKey, value.remindersEnabled);
    await prefs.setBool(focusKey, value.focusEnabled);
  }
}

final notificationPreferencesStoreProvider =
    Provider<NotificationPreferencesStore>(
  (ref) => const NotificationPreferencesStore(),
);

final notificationPreferencesProvider =
    FutureProvider<NotificationPreferences>((ref) {
  return ref.watch(notificationPreferencesStoreProvider).load();
});
