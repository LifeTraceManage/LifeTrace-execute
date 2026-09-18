import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/background/background_sync.dart';
import '../../core/cloud/cloud_contract.dart';
import '../../core/cloud/cloud_device_contract.dart';
import '../../core/cloud/lifetrace_cloud_client.dart';
import '../../core/cloud/privacy_export_writer.dart';
import '../tasks/task_providers.dart';

final profileCloudClientProvider = Provider<LifeTraceCloudClient>(
  (ref) => LifeTraceCloudClient(),
);

final cloudProfileProvider = FutureProvider<CloudUser?>((ref) async {
  final session = await ref.watch(currentSessionProvider.future);
  if (session == null) return null;
  final manager = ref.watch(cloudSessionManagerProvider);
  final client = ref.watch(profileCloudClientProvider);
  return manager.authorized(
    (fresh) => client.me(
      baseUrl: fresh.baseUrl,
      accessToken: fresh.accessToken,
    ),
  );
});


final cloudDevicesProvider =
    FutureProvider<List<CloudDeviceInstallation>>((ref) async {
  if (kIsWeb) return const <CloudDeviceInstallation>[];
  final manager = ref.watch(cloudSessionManagerProvider);
  final client = ref.watch(profileCloudClientProvider);
  final session = await ref.watch(currentSessionProvider.future);
  if (session == null) return const <CloudDeviceInstallation>[];
  return manager.authorized(
    (fresh) => client.listDevices(
      baseUrl: fresh.baseUrl,
      accessToken: fresh.accessToken,
    ),
  );
});

final cloudSessionsProvider =
    FutureProvider<List<CloudAuthSessionInfo>>((ref) async {
  if (kIsWeb) return const <CloudAuthSessionInfo>[];
  final manager = ref.watch(cloudSessionManagerProvider);
  final client = ref.watch(profileCloudClientProvider);
  final session = await ref.watch(currentSessionProvider.future);
  if (session == null) return const <CloudAuthSessionInfo>[];
  return manager.authorized(
    (fresh) => client.listSessions(
      baseUrl: fresh.baseUrl,
      accessToken: fresh.accessToken,
    ),
  );
});

final syncUnresolvedConflictCountProvider = StreamProvider<int>((ref) async* {
  if (kIsWeb) {
    yield 0;
    return;
  }
  final database = ref.watch(appDatabaseProvider);
  final userId = await ref.watch(currentUserIdProvider.future);
  if (database == null || userId == null) {
    yield 0;
    return;
  }
  final count = database.syncConflicts.id.count();
  final query = database.selectOnly(database.syncConflicts)
    ..addColumns([count])
    ..where(
      database.syncConflicts.userId.equals(userId) &
          database.syncConflicts.resolved.equals(false),
    );
  yield* query.watchSingle().map((row) => row.read(count) ?? 0);
});

final privacyPolicyProvider =
    FutureProvider<Map<String, dynamic>?>((ref) async {
  final session = await ref.watch(currentSessionProvider.future);
  if (session == null) return null;
  final manager = ref.watch(cloudSessionManagerProvider);
  final client = ref.watch(profileCloudClientProvider);
  return manager.authorized(
    (fresh) => client.privacyPolicy(
      baseUrl: fresh.baseUrl,
      accessToken: fresh.accessToken,
    ),
  );
});

final profileDataCommandsProvider =
    Provider<ProfileDataCommands>(ProfileDataCommands.new);

class ProfileDataCommands {
  ProfileDataCommands(this.ref);

  final Ref ref;

  Future<String> exportPrivacyData() async {
    final client = ref.read(profileCloudClientProvider);
    final manager = ref.read(cloudSessionManagerProvider);
    final payload = await manager.authorized(
      (session) => client.privacyExport(
        baseUrl: session.baseUrl,
        accessToken: session.accessToken,
      ),
    );
    return writePrivacyExport(payload);
  }

  Future<void> deleteCloudAccount() async {
    final client = ref.read(profileCloudClientProvider);
    final manager = ref.read(cloudSessionManagerProvider);
    await manager.authorized(
      (session) => client.deleteAccount(
        baseUrl: session.baseUrl,
        accessToken: session.accessToken,
      ),
    );
    await _clearInvalidatedCloudSession(ref);
  }
}

final profileSecurityCommandsProvider =
    Provider<ProfileSecurityCommands>(ProfileSecurityCommands.new);

class ProfileSecurityCommands {
  ProfileSecurityCommands(this.ref);

  final Ref ref;

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (currentPassword.isEmpty) {
      throw ArgumentError.value(currentPassword, 'currentPassword', '请输入当前密码');
    }
    if (newPassword.isEmpty) {
      throw ArgumentError.value(newPassword, 'newPassword', '请输入新密码');
    }
    final client = ref.read(profileCloudClientProvider);
    final manager = ref.read(cloudSessionManagerProvider);
    await manager.authorized(
      (session) => client.changePassword(
        baseUrl: session.baseUrl,
        accessToken: session.accessToken,
        currentPassword: currentPassword,
        newPassword: newPassword,
      ),
    );
    await _clearInvalidatedCloudSession(ref);
  }

  Future<void> logoutAll() async {
    final client = ref.read(profileCloudClientProvider);
    final manager = ref.read(cloudSessionManagerProvider);
    await manager.authorized(
      (session) => client.logoutAll(
        baseUrl: session.baseUrl,
        accessToken: session.accessToken,
      ),
    );
    await _clearInvalidatedCloudSession(ref);
  }
}

final cloudDeviceCommandsProvider =
    Provider<CloudDeviceCommands>(CloudDeviceCommands.new);

class CloudDeviceCommands {
  CloudDeviceCommands(this.ref);

  final Ref ref;

  Future<void> renameDevice(
    CloudDeviceInstallation device,
    String name,
  ) async {
    final client = ref.read(profileCloudClientProvider);
    final manager = ref.read(cloudSessionManagerProvider);
    await manager.authorized(
      (session) => client.updateDevice(
        baseUrl: session.baseUrl,
        accessToken: session.accessToken,
        deviceId: device.id,
        deviceName: name,
      ),
    );
    _refresh();
  }

  Future<void> revokeDevice(CloudDeviceInstallation device) async {
    if (device.current) {
      throw StateError('当前设备请使用“断开连接”退出，不能从设备管理中撤销');
    }
    final client = ref.read(profileCloudClientProvider);
    final manager = ref.read(cloudSessionManagerProvider);
    await manager.authorized(
      (session) => client.revokeDevice(
        baseUrl: session.baseUrl,
        accessToken: session.accessToken,
        deviceId: device.id,
      ),
    );
    _refresh();
  }

  Future<void> revokeSession(CloudAuthSessionInfo sessionInfo) async {
    if (sessionInfo.current) {
      throw StateError('当前会话请使用“断开连接”退出，不能从会话列表中撤销');
    }
    final client = ref.read(profileCloudClientProvider);
    final manager = ref.read(cloudSessionManagerProvider);
    await manager.authorized(
      (session) => client.revokeSession(
        baseUrl: session.baseUrl,
        accessToken: session.accessToken,
        sessionId: sessionInfo.id,
      ),
    );
    _refresh();
  }

  void _refresh() {
    ref.invalidate(cloudDevicesProvider);
    ref.invalidate(cloudSessionsProvider);
  }
}

Future<void> _clearInvalidatedCloudSession(Ref ref) async {
  await ref.read(cloudSessionManagerProvider).clearLocalSession();
  if (!kIsWeb) {
    await BackgroundSyncScheduler.cancelForLogout();
  }
  ref.invalidate(currentSessionProvider);
  ref.invalidate(currentUserIdProvider);
  ref.invalidate(cloudProfileProvider);
  ref.invalidate(cloudDevicesProvider);
  ref.invalidate(cloudSessionsProvider);
  ref.invalidate(privacyPolicyProvider);
}
