import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/core/notifications/notification_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('notification preferences default to enabled', () async {
    const store = NotificationPreferencesStore();

    final value = await store.load();

    expect(value.remindersEnabled, isTrue);
    expect(value.focusEnabled, isTrue);
  });

  test('notification preferences persist independently', () async {
    const store = NotificationPreferencesStore();

    await store.save(
      const NotificationPreferences(
        remindersEnabled: false,
        focusEnabled: true,
      ),
    );

    var value = await store.load();
    expect(value.remindersEnabled, isFalse);
    expect(value.focusEnabled, isTrue);

    await store.save(value.copyWith(focusEnabled: false));
    value = await store.load();
    expect(value.remindersEnabled, isFalse);
    expect(value.focusEnabled, isFalse);
  });
}
