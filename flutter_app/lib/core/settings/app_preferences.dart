import 'package:shared_preferences/shared_preferences.dart';

enum UiDensityPreference {
  compact,
  standard,
  comfortable;

  static UiDensityPreference fromWire(String? value) {
    return UiDensityPreference.values.firstWhere(
      (item) => item.name == value,
      orElse: () => UiDensityPreference.standard,
    );
  }
}

class AppPreferencesState {
  const AppPreferencesState({
    required this.notificationsEnabled,
    required this.reminderNotificationsEnabled,
    required this.focusNotificationsEnabled,
    required this.uiDensity,
    required this.weekStartsMonday,
  });

  static const defaults = AppPreferencesState(
    notificationsEnabled: true,
    reminderNotificationsEnabled: true,
    focusNotificationsEnabled: true,
    uiDensity: UiDensityPreference.standard,
    weekStartsMonday: true,
  );

  final bool notificationsEnabled;
  final bool reminderNotificationsEnabled;
  final bool focusNotificationsEnabled;
  final UiDensityPreference uiDensity;
  final bool weekStartsMonday;

  double get uiScale => switch (uiDensity) {
        UiDensityPreference.compact => 0.92,
        UiDensityPreference.standard => 1.0,
        UiDensityPreference.comfortable => 1.08,
      };
}

class AppPreferencesStore {
  static const _notificationsEnabled = 'settings.notifications.enabled';
  static const _reminderNotificationsEnabled =
      'settings.notifications.reminders.enabled';
  static const _focusNotificationsEnabled =
      'settings.notifications.focus.enabled';
  static const _uiDensity = 'settings.appearance.ui_density';
  static const _weekStartsMonday = 'settings.general.week_starts_monday';

  Future<AppPreferencesState> load() async {
    final preferences = await SharedPreferences.getInstance();
    return AppPreferencesState(
      notificationsEnabled:
          preferences.getBool(_notificationsEnabled) ??
              AppPreferencesState.defaults.notificationsEnabled,
      reminderNotificationsEnabled:
          preferences.getBool(_reminderNotificationsEnabled) ??
              AppPreferencesState.defaults.reminderNotificationsEnabled,
      focusNotificationsEnabled:
          preferences.getBool(_focusNotificationsEnabled) ??
              AppPreferencesState.defaults.focusNotificationsEnabled,
      uiDensity: UiDensityPreference.fromWire(
        preferences.getString(_uiDensity),
      ),
      weekStartsMonday:
          preferences.getBool(_weekStartsMonday) ??
              AppPreferencesState.defaults.weekStartsMonday,
    );
  }

  Future<void> setNotificationsEnabled(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_notificationsEnabled, value);
  }

  Future<void> setReminderNotificationsEnabled(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_reminderNotificationsEnabled, value);
  }

  Future<void> setFocusNotificationsEnabled(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_focusNotificationsEnabled, value);
  }

  Future<void> setUiDensity(UiDensityPreference value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_uiDensity, value.name);
  }

  Future<void> setWeekStartsMonday(bool value) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_weekStartsMonday, value);
  }
}
