import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/core/preferences/app_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('appearance preferences default to comfortable normal motion', () async {
    const store = AppPreferencesStore();

    final value = await store.load();

    expect(value.density, DensityPreference.comfortable);
    expect(value.fontScale, FontScalePreference.normal);
    expect(value.reduceMotion, isFalse);
  });

  test('appearance preferences persist with existing LifeTrace namespace',
      () async {
    const store = AppPreferencesStore();

    await store.save(
      const AppPreferences(
        density: DensityPreference.compact,
        fontScale: FontScalePreference.large,
        reduceMotion: true,
      ),
    );

    final value = await store.load();
    expect(AppPreferencesStore.storageKey, 'lifetrace.app-preferences.v1');
    expect(value.density, DensityPreference.compact);
    expect(value.fontScale, FontScalePreference.large);
    expect(value.fontScale.scale, 1.15);
    expect(value.reduceMotion, isTrue);
  });

  test('invalid stored appearance value falls back safely', () async {
    SharedPreferences.setMockInitialValues({
      AppPreferencesStore.storageKey: '{invalid',
    });
    const store = AppPreferencesStore();

    final value = await store.load();

    expect(value.density, DensityPreference.comfortable);
    expect(value.fontScale, FontScalePreference.normal);
    expect(value.reduceMotion, isFalse);
  });
}
