import '../identity/device_identity_store.dart';
import 'cloud_contract.dart';
import 'lifetrace_cloud_client.dart';
import 'secure_session_store.dart';

abstract interface class CloudSessionAccess {
  Future<StoredCloudSession?> currentSession();

  Future<T> authorized<T>(
    Future<T> Function(StoredCloudSession session) block,
  );
}

class CloudSessionManager implements CloudSessionAccess {
  CloudSessionManager({
    CloudSessionStore? sessionStore,
    LifeTraceCloudClient? authClient,
    DeviceIdentityStore? identityStore,
  })  : _sessionStore = sessionStore ?? SecureSessionStore(),
        _authClient = authClient ?? LifeTraceCloudClient(),
        _identityStore = identityStore ?? DeviceIdentityStore();

  static const _accessTokenSkewSeconds = 60;

  final CloudSessionStore _sessionStore;
  final LifeTraceCloudClient _authClient;
  final DeviceIdentityStore _identityStore;

  @override
  Future<StoredCloudSession?> currentSession() => _sessionStore.load();

  Future<StoredCloudSession> login({
    required String baseUrl,
    required String email,
    required String password,
    required String deviceName,
    required String clientVersion,
  }) async {
    final normalized = _authClient.normalizeBaseUrl(baseUrl);
    final authCapabilities = await _authClient.authCapabilities(normalized);
    if (authCapabilities.supportedApps.isNotEmpty &&
        !authCapabilities.supportedApps.contains(CloudContract.appId)) {
      throw StateError('LifeTrace Cloud 尚未声明支持 ${CloudContract.appId}');
    }

    final syncCapabilities = await _authClient.syncCapabilities(normalized);
    if (syncCapabilities.protocolVersion != CloudContract.protocolVersion) {
      throw StateError(
        'Sync 协议版本不兼容：server=${syncCapabilities.protocolVersion}, client=${CloudContract.protocolVersion}',
      );
    }
    if (!syncCapabilities.supportedEntityTypes
        .containsAll(CloudContract.requiredSyncEntityTypes)) {
      final missing = CloudContract.requiredSyncEntityTypes
          .difference(syncCapabilities.supportedEntityTypes)
          .join(', ');
      throw StateError('Cloud 缺少 Execute 必需实体：$missing');
    }

    final result = await _authClient.login(
      baseUrl: normalized,
      email: email,
      password: password,
      deviceId: await _identityStore.getOrCreate(),
      deviceName: deviceName,
      clientVersion: clientVersion,
    );
    _validateScopes(result.scopes);

    final stored = StoredCloudSession(
      baseUrl: normalized,
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
      accessTokenExpiresAtEpochSeconds:
          DateTime.now().millisecondsSinceEpoch ~/ 1000 + result.expiresInSeconds,
      userId: result.user.id,
      email: result.user.email,
      displayName: result.user.displayName,
      sessionId: result.sessionId,
      scopes: result.scopes,
      protocolVersion: syncCapabilities.protocolVersion,
      schemaVersion: syncCapabilities.schemaVersion,
    );
    await _sessionStore.save(stored);
    return stored;
  }

  Future<StoredCloudSession> requireFreshSession({bool forceRefresh = false}) async {
    final current = await _sessionStore.load();
    if (current == null) throw StateError('尚未连接 LifeTrace Cloud');
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (!forceRefresh &&
        current.accessTokenExpiresAtEpochSeconds > now + _accessTokenSkewSeconds) {
      return current;
    }
    return _refresh(current);
  }

  @override
  Future<T> authorized<T>(
    Future<T> Function(StoredCloudSession session) block,
  ) async {
    final session = await requireFreshSession();
    try {
      return await block(session);
    } on CloudApiException catch (error) {
      if (!error.isExpiredAccessToken) rethrow;
      final refreshed = await requireFreshSession(forceRefresh: true);
      return block(refreshed);
    }
  }

  Future<void> logout() async {
    final session = await _sessionStore.load();
    if (session != null) {
      try {
        final fresh = await requireFreshSession();
        await _authClient.logout(
          baseUrl: fresh.baseUrl,
          accessToken: fresh.accessToken,
        );
      } finally {
        await _sessionStore.clear();
      }
    }
  }

  Future<StoredCloudSession> _refresh(StoredCloudSession current) async {
    final refreshToken = current.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      throw StateError('Cloud 会话没有可用 Refresh Token，请重新登录');
    }
    final result = await _authClient.refresh(
      baseUrl: current.baseUrl,
      refreshToken: refreshToken,
      deviceId: await _identityStore.getOrCreate(),
    );
    _validateScopes(result.scopes);
    final stored = current.copyWith(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken ?? refreshToken,
      accessTokenExpiresAtEpochSeconds:
          DateTime.now().millisecondsSinceEpoch ~/ 1000 + result.expiresInSeconds,
      userId: result.user.id,
      email: result.user.email,
      displayName: result.user.displayName,
      sessionId: result.sessionId,
      scopes: result.scopes,
    );
    await _sessionStore.save(stored);
    return stored;
  }

  void _validateScopes(List<String> scopes) {
    final missing = CloudContract.requestedScopes.toSet().difference(scopes.toSet());
    if (missing.isNotEmpty) {
      throw StateError('Cloud 会话缺少 Execute 权限：${missing.join(', ')}');
    }
  }
}
