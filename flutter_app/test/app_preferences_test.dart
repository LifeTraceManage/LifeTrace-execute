import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:lifetrace_execute/core/settings/app_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('app preferences use production defaults', () async {
    final value = await AppPreferencesStore().load();

    expect(value.notificationsEnabled, isTrue);
    expect(value.reminderNotificationsEnabled, isTrue);
    expect(value.focusNotificationsEnabled, isTrue);
    expect(value.uiDensity, UiDensityPreference.standard);
    expect(value.weekStartsMonday, isTrue);
    expect(value.uiScale, 1);
  });

  test('app preferences persist notification, density and calendar settings',
      () async {
    final store = AppPreferencesStore();

    await store.setNotificationsEnabled(false);
    await store.setReminderNotificationsEnabled(false);
    await store.setFocusNotificationsEnabled(false);
    await store.setUiDensity(UiDensityPreference.comfortable);
    await store.setWeekStartsMonday(false);

    final value = await store.load();
    expect(value.notificationsEnabled, isFalse);
    expect(value.reminderNotificationsEnabled, isFalse);
    expect(value.focusNotificationsEnabled, isFalse);
    expect(value.uiDensity, UiDensityPreference.comfortable);
    expect(value.uiScale, 1.08);
    expect(value.weekStartsMonday, isFalse);
  });
}
