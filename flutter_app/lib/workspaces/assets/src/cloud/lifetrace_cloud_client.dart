import 'cloud_contract.dart';
import 'cloud_http_transport.dart';

class CloudAuthCapabilities {
  const CloudAuthCapabilities({required this.supportedApps});
  final Set<String> supportedApps;
}

class CloudSyncCapabilities {
  const CloudSyncCapabilities({
    required this.protocolVersion,
    required this.schemaVersion,
    required this.supportedEntityTypes,
  });
  final int protocolVersion;
  final int schemaVersion;
  final Set<String> supportedEntityTypes;
}

class LifeTraceCloudClient {
  LifeTraceCloudClient({CloudHttpTransport? transport})
      : _transport = transport ?? CloudHttpTransport();
  final CloudHttpTransport _transport;

  String normalizeBaseUrl(String raw) => _transport.normalizeBaseUrl(raw);

  Future<CloudAuthCapabilities> authCapabilities(String baseUrl) async {
    final json = await _transport.requestJson(
      method: 'GET',
      baseUrl: baseUrl,
      path: '/api/v1/auth/capabilities',
    );
    return CloudAuthCapabilities(
      supportedApps: (json['supportedApps'] as List<dynamic>? ?? const [])
          .whereType<String>().toSet(),
    );
  }

  Future<CloudSyncCapabilities> syncCapabilities(String baseUrl) async {
    final json = await _transport.requestJson(
      method: 'GET',
      baseUrl: baseUrl,
      path: '/api/v1/sync/capabilities',
    );
    return CloudSyncCapabilities(
      protocolVersion: (json['protocolVersion'] as num?)?.toInt() ?? -1,
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? -1,
      supportedEntityTypes:
          (json['supportedEntityTypes'] as List<dynamic>? ?? const [])
              .whereType<String>().toSet(),
    );
  }

  Future<CloudAuthResult> login({
    required String baseUrl,
    required String email,
    required String password,
    required String deviceId,
  }) async {
    final json = await _transport.requestJson(
      method: 'POST',
      baseUrl: baseUrl,
      path: '/api/v1/auth/login',
      body: {
        'email': email.trim(),
        'password': password,
        'appId': CloudContract.appId,
        'deviceId': deviceId,
        'deviceName': 'LifeTrace Assets',
        'platform': CloudContract.platform,
        'clientVersion': CloudContract.clientVersion,
        'requestedScopes': CloudContract.requestedScopes,
        'publicDevice': false,
      },
    );
    return CloudAuthResult.fromJson(json);
  }

  Future<CloudAuthResult> refresh({
    required String baseUrl,
    required String refreshToken,
    required String deviceId,
  }) async {
    final json = await _transport.requestJson(
      method: 'POST',
      baseUrl: baseUrl,
      path: '/api/v1/auth/refresh',
      body: {
        'refreshToken': refreshToken,
        'appId': CloudContract.appId,
        'deviceId': deviceId,
      },
    );
    return CloudAuthResult.fromJson(json);
  }

  Future<void> logout({
    required String baseUrl,
    required String accessToken,
  }) async {
    await _transport.requestJson(
      method: 'POST',
      baseUrl: baseUrl,
      path: '/api/v1/auth/logout',
      accessToken: accessToken,
    );
  }
}
