import 'cloud_contract.dart';
import 'device_identity_store.dart';
import 'lifetrace_cloud_client.dart';
import 'secure_session_store.dart';

abstract interface class CloudSessionAccess {
  Future<StoredCloudSession?> currentSession();

  Future<StoredCloudSession> login({
    required String baseUrl,
    required String email,
    required String password,
  });

  Future<T> authorized<T>(
    Future<T> Function(StoredCloudSession session) block,
  );

  Future<void> logout();
}

class CloudSessionManager implements CloudSessionAccess {
  CloudSessionManager({
    SecureSessionStore? sessionStore,
    LifeTraceCloudClient? cloudClient,
    DeviceIdentityStore? identityStore,
  })  : _sessionStore = sessionStore ?? SecureSessionStore(),
        _cloudClient = cloudClient ?? LifeTraceCloudClient(),
        _identityStore = identityStore ?? DeviceIdentityStore();

  static const _accessTokenSkewSeconds = 60;
  final SecureSessionStore _sessionStore;
  final LifeTraceCloudClient _cloudClient;
  final DeviceIdentityStore _identityStore;

  @override
  Future<StoredCloudSession?> currentSession() => _sessionStore.load();

  @override
  Future<StoredCloudSession> login({
    required String baseUrl,
    required String email,
    required String password,
  }) async {
    final normalized = _cloudClient.normalizeBaseUrl(baseUrl);
    final auth = await _cloudClient.authCapabilities(normalized);
    if (auth.supportedApps.isNotEmpty &&
        !auth.supportedApps.contains(CloudContract.appId)) {
      throw StateError('LifeTrace Cloud 尚未声明支持 ${CloudContract.appId}');
    }
    final sync = await _cloudClient.syncCapabilities(normalized);
    if (sync.protocolVersion != CloudContract.protocolVersion) {
      throw StateError(
        'Sync 协议版本不兼容：server=${sync.protocolVersion}, client=${CloudContract.protocolVersion}',
      );
    }
    final missingEntities = CloudContract.requiredSyncEntityTypes
        .difference(sync.supportedEntityTypes);
    if (missingEntities.isNotEmpty) {
      throw StateError('Cloud 缺少 Assets 实体：${missingEntities.join(', ')}');
    }
    final result = await _cloudClient.login(
      baseUrl: normalized,
      email: email,
      password: password,
      deviceId: await _identityStore.getOrCreate(),
    );
    _validateScopes(result.scopes);
    final session = StoredCloudSession(
      baseUrl: normalized,
      accessToken: result.accessToken,
      refreshToken: result.refreshToken,
      accessTokenExpiresAtEpochSeconds:
          DateTime.now().millisecondsSinceEpoch ~/ 1000 + result.expiresInSeconds,
      userId: result.user.id,
      email: result.user.email,
      sessionId: result.sessionId,
      scopes: result.scopes,
      schemaVersion: sync.schemaVersion,
    );
    await _sessionStore.save(session);
    return session;
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
      return block(await requireFreshSession(forceRefresh: true));
    }
  }

  Future<StoredCloudSession> requireFreshSession({
    bool forceRefresh = false,
  }) async {
    final current = await _sessionStore.load();
    if (current == null) throw StateError('尚未连接 LifeTrace Cloud');
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (!forceRefresh &&
        current.accessTokenExpiresAtEpochSeconds >
            now + _accessTokenSkewSeconds) {
      return current;
    }
    final refreshToken = current.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      throw StateError('Cloud 会话已过期，请重新登录');
    }
    final result = await _cloudClient.refresh(
      baseUrl: current.baseUrl,
      refreshToken: refreshToken,
      deviceId: await _identityStore.getOrCreate(),
    );
    _validateScopes(result.scopes);
    final refreshed = current.copyWith(
      accessToken: result.accessToken,
      refreshToken: result.refreshToken ?? refreshToken,
      accessTokenExpiresAtEpochSeconds:
          DateTime.now().millisecondsSinceEpoch ~/ 1000 + result.expiresInSeconds,
      userId: result.user.id,
      email: result.user.email,
      sessionId: result.sessionId,
      scopes: result.scopes,
    );
    await _sessionStore.save(refreshed);
    return refreshed;
  }

  @override
  Future<void> logout() async {
    final current = await _sessionStore.load();
    if (current == null) return;
    try {
      final fresh = await requireFreshSession();
      await _cloudClient.logout(
        baseUrl: fresh.baseUrl,
        accessToken: fresh.accessToken,
      );
    } finally {
      await _sessionStore.clear();
    }
  }

  void _validateScopes(List<String> scopes) {
    final missing =
        CloudContract.requestedScopes.toSet().difference(scopes.toSet());
    if (missing.isNotEmpty) {
      throw StateError('Cloud 会话缺少 Assets 权限：${missing.join(', ')}');
    }
  }
}
