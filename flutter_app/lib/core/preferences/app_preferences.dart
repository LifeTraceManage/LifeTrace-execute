import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum DensityPreference {
  comfortable('comfortable'),
  compact('compact');

  const DensityPreference(this.wireValue);
  final String wireValue;

  static DensityPreference fromWire(Object? value) =>
      value == 'compact' ? compact : comfortable;
}

enum FontScalePreference {
  small('small', .90),
  normal('normal', 1.0),
  large('large', 1.15);

  const FontScalePreference(this.wireValue, this.scale);
  final String wireValue;
  final double scale;

  static FontScalePreference fromWire(Object? value) => switch (value) {
        'small' => small,
        'large' => large,
        _ => normal,
      };
}

class AppPreferences {
  const AppPreferences({
    this.density = DensityPreference.comfortable,
    this.fontScale = FontScalePreference.normal,
    this.reduceMotion = false,
  });

  final DensityPreference density;
  final FontScalePreference fontScale;
  final bool reduceMotion;

  AppPreferences copyWith({
    DensityPreference? density,
    FontScalePreference? fontScale,
    bool? reduceMotion,
  }) =>
      AppPreferences(
        density: density ?? this.density,
        fontScale: fontScale ?? this.fontScale,
        reduceMotion: reduceMotion ?? this.reduceMotion,
      );

  Map<String, dynamic> toJson() => {
        'density': density.wireValue,
        'fontScale': fontScale.wireValue,
        'reduceMotion': reduceMotion,
      };

  factory AppPreferences.fromJson(Object? raw) {
    if (raw is! Map) return const AppPreferences();
    final json = Map<String, dynamic>.from(raw);
    return AppPreferences(
      density: DensityPreference.fromWire(json['density']),
      fontScale: FontScalePreference.fromWire(json['fontScale']),
      reduceMotion:
          json['reduceMotion'] is bool ? json['reduceMotion'] as bool : false,
    );
  }
}

class AppPreferencesStore {
  const AppPreferencesStore();

  /// Matches the existing LifeTrace desktop preference namespace.
  static const storageKey = 'lifetrace.app-preferences.v1';

  Future<AppPreferences> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return const AppPreferences();
    try {
      return AppPreferences.fromJson(jsonDecode(raw));
    } catch (_) {
      return const AppPreferences();
    }
  }

  Future<void> save(AppPreferences value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(value.toJson()));
  }
}

final appPreferencesStoreProvider = Provider<AppPreferencesStore>(
  (ref) => const AppPreferencesStore(),
);

final appPreferencesProvider = FutureProvider<AppPreferences>((ref) {
  return ref.watch(appPreferencesStoreProvider).load();
});

final appPreferencesCommandsProvider =
    Provider<AppPreferencesCommands>(AppPreferencesCommands.new);

class AppPreferencesCommands {
  AppPreferencesCommands(this.ref);

  final Ref ref;

  Future<void> setDensity(DensityPreference value) =>
      _update((current) => current.copyWith(density: value));

  Future<void> setFontScale(FontScalePreference value) =>
      _update((current) => current.copyWith(fontScale: value));

  Future<void> setReduceMotion(bool value) =>
      _update((current) => current.copyWith(reduceMotion: value));

  Future<void> _update(
    AppPreferences Function(AppPreferences current) transform,
  ) async {
    final current = await ref.read(appPreferencesProvider.future);
    final next = transform(current);
    await ref.read(appPreferencesStoreProvider).save(next);
    ref.invalidate(appPreferencesProvider);
  }
}
