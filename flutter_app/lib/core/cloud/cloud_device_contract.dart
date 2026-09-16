class CloudDeviceInstallation {
  const CloudDeviceInstallation({
    required this.id,
    required this.externalDeviceId,
    required this.deviceName,
    required this.appId,
    required this.platform,
    required this.status,
    required this.firstSeenAt,
    required this.lastSeenAt,
    required this.current,
    this.deviceGroupId,
    this.clientVersion,
    this.lastLoginAt,
    this.lastSyncAt,
    this.revokedAt,
  });

  final String id;
  final String externalDeviceId;
  final String? deviceGroupId;
  final String deviceName;
  final String appId;
  final String platform;
  final String status;
  final String? clientVersion;
  final String firstSeenAt;
  final String lastSeenAt;
  final String? lastLoginAt;
  final String? lastSyncAt;
  final String? revokedAt;
  final bool current;

  factory CloudDeviceInstallation.fromJson(Map<String, dynamic> json) =>
      CloudDeviceInstallation(
        id: _requiredString(json, 'id'),
        externalDeviceId: _requiredString(json, 'externalDeviceId'),
        deviceGroupId: _nullableString(json['deviceGroupId']),
        deviceName: _requiredString(json, 'deviceName'),
        appId: _requiredString(json, 'appId'),
        platform: _requiredString(json, 'platform'),
        status: _requiredString(json, 'status'),
        clientVersion: _nullableString(json['clientVersion']),
        firstSeenAt: _requiredString(json, 'firstSeenAt'),
        lastSeenAt: _requiredString(json, 'lastSeenAt'),
        lastLoginAt: _nullableString(json['lastLoginAt']),
        lastSyncAt: _nullableString(json['lastSyncAt']),
        revokedAt: _nullableString(json['revokedAt']),
        current: json['current'] == true,
      );
}

class CloudAuthSessionInfo {
  const CloudAuthSessionInfo({
    required this.id,
    required this.appId,
    required this.deviceId,
    required this.sessionType,
    required this.status,
    required this.scopes,
    required this.publicDevice,
    required this.createdAt,
    required this.lastSeenAt,
    required this.idleExpiresAt,
    required this.absoluteExpiresAt,
    required this.current,
    this.revokedAt,
  });

  final String id;
  final String appId;
  final String deviceId;
  final String sessionType;
  final String status;
  final List<String> scopes;
  final bool publicDevice;
  final String createdAt;
  final String lastSeenAt;
  final String idleExpiresAt;
  final String absoluteExpiresAt;
  final String? revokedAt;
  final bool current;

  factory CloudAuthSessionInfo.fromJson(Map<String, dynamic> json) =>
      CloudAuthSessionInfo(
        id: _requiredString(json, 'id'),
        appId: _requiredString(json, 'appId'),
        deviceId: _requiredString(json, 'deviceId'),
        sessionType: _requiredString(json, 'sessionType'),
        status: _requiredString(json, 'status'),
        scopes: (json['scopes'] as List<dynamic>? ?? const [])
            .map((value) => value.toString())
            .toList(growable: false),
        publicDevice: json['publicDevice'] == true,
        createdAt: _requiredString(json, 'createdAt'),
        lastSeenAt: _requiredString(json, 'lastSeenAt'),
        idleExpiresAt: _requiredString(json, 'idleExpiresAt'),
        absoluteExpiresAt: _requiredString(json, 'absoluteExpiresAt'),
        revokedAt: _nullableString(json['revokedAt']),
        current: json['current'] == true,
      );
}

List<CloudDeviceInstallation> parseCloudDeviceList(
  Map<String, dynamic> json,
) {
  final raw = json['devices'];
  if (raw is! List) {
    throw const FormatException('Device list is missing devices');
  }
  return raw
      .map(
        (value) => CloudDeviceInstallation.fromJson(
          Map<String, dynamic>.from(value as Map),
        ),
      )
      .toList(growable: false);
}

List<CloudAuthSessionInfo> parseCloudSessionList(
  Map<String, dynamic> json,
) {
  final raw = json['sessions'];
  if (raw is! List) {
    throw const FormatException('Session list is missing sessions');
  }
  return raw
      .map(
        (value) => CloudAuthSessionInfo.fromJson(
          Map<String, dynamic>.from(value as Map),
        ),
      )
      .toList(growable: false);
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = _nullableString(json[key]);
  if (value == null) throw FormatException('Missing $key');
  return value;
}

String? _nullableString(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}
