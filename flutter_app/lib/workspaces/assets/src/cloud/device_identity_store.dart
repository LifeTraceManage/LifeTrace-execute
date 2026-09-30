import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class DeviceIdentityStore {
  DeviceIdentityStore({SharedPreferencesAsync? preferences, Uuid? uuid})
      : _preferences = preferences ?? SharedPreferencesAsync(),
        _uuid = uuid ?? const Uuid();

  static const _key = 'lifetrace.assets.device_id';
  final SharedPreferencesAsync _preferences;
  final Uuid _uuid;

  Future<String> getOrCreate() async {
    final existing = await _preferences.getString(_key);
    if (existing != null && existing.isNotEmpty) return existing;
    final created = _uuid.v4();
    await _preferences.setString(_key, created);
    return created;
  }
}
