import 'cloud_contract.dart';
import 'cloud_device_contract.dart';
import 'cloud_http_transport.dart';

class CloudAuthCapabilities {
  const CloudAuthCapabilities({
    required this.registrationMode,
    required this.supportedApps,
  });

  final String registrationMode;
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
      registrationMode: json['registrationMode'] as String? ?? '',
      supportedApps: (json['supportedApps'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toSet(),
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
              .whereType<String>()
              .toSet(),
    );
  }

  Future<CloudAuthResult> login({
    required String baseUrl,
    required String email,
    required String password,
    required String deviceId,
    required String deviceName,
    required String clientVersion,
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
        'deviceName': deviceName,
        'platform': CloudContract.platform,
        'clientVersion': clientVersion,
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

  Future<void> logout({required String baseUrl, required String accessToken}) async {
    await _transport.requestJson(
      method: 'POST',
      baseUrl: baseUrl,
      path: '/api/v1/auth/logout',
      accessToken: accessToken,
    );
  }

  Future<CloudUser> me({required String baseUrl, required String accessToken}) async {
    final json = await _transport.requestJson(
      method: 'GET',
      baseUrl: baseUrl,
      path: '/api/v1/auth/me',
      accessToken: accessToken,
    );
    return CloudUser.fromJson(json);
  }

  Future<List<CloudDeviceInstallation>> listDevices({
    required String baseUrl,
    required String accessToken,
  }) async {
    final json = await _transport.requestJson(
      method: 'GET',
      baseUrl: baseUrl,
      path: '/api/v1/auth/devices',
      accessToken: accessToken,
    );
    return parseCloudDeviceList(json);
  }

  Future<CloudDeviceInstallation> updateDevice({
    required String baseUrl,
    required String accessToken,
    required String deviceId,
    required String deviceName,
  }) async {
    final cleanName = deviceName.trim();
    if (cleanName.isEmpty) {
      throw ArgumentError.value(deviceName, 'deviceName', '设备名称不能为空');
    }
    final json = await _transport.requestJson(
      method: 'PATCH',
      baseUrl: baseUrl,
      path: '/api/v1/auth/devices/$deviceId',
      accessToken: accessToken,
      body: {'deviceName': cleanName},
    );
    return CloudDeviceInstallation.fromJson(json);
  }

  Future<void> revokeDevice({
    required String baseUrl,
    required String accessToken,
    required String deviceId,
  }) async {
    await _transport.requestJson(
      method: 'POST',
      baseUrl: baseUrl,
      path: '/api/v1/auth/devices/$deviceId/revoke',
      accessToken: accessToken,
    );
  }

  Future<List<CloudAuthSessionInfo>> listSessions({
    required String baseUrl,
    required String accessToken,
  }) async {
    final json = await _transport.requestJson(
      method: 'GET',
      baseUrl: baseUrl,
      path: '/api/v1/auth/sessions',
      accessToken: accessToken,
    );
    return parseCloudSessionList(json);
  }

  Future<void> revokeSession({
    required String baseUrl,
    required String accessToken,
    required String sessionId,
  }) async {
    await _transport.requestJson(
      method: 'DELETE',
      baseUrl: baseUrl,
      path: '/api/v1/auth/sessions/$sessionId',
      accessToken: accessToken,
    );
  }
}
