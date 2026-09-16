import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/core/cloud/cloud_contract.dart';
import 'package:lifetrace_execute/core/cloud/cloud_device_contract.dart';
import 'package:lifetrace_execute/core/cloud/cloud_http_transport.dart';
import 'package:lifetrace_execute/core/cloud/lifetrace_cloud_client.dart';

void main() {
  test('Execute requests device and session management scopes', () {
    expect(
      CloudContract.requestedScopes,
      containsAll([
        'devices:read',
        'devices:write',
        'sessions:read',
        'sessions:write',
      ]),
    );
  });

  test('parses typed Cloud device and session lists', () {
    final devices = parseCloudDeviceList({
      'devices': [
        _deviceJson(
          id: 'installation-1',
          name: 'Pixel',
          current: true,
        ),
      ],
    });
    final sessions = parseCloudSessionList({
      'sessions': [
        _sessionJson(
          id: 'session-1',
          deviceId: 'installation-1',
          current: true,
        ),
      ],
    });

    expect(devices, hasLength(1));
    expect(devices.single.deviceName, 'Pixel');
    expect(devices.single.current, isTrue);
    expect(devices.single.lastSyncAt, '2026-09-16T02:00:00Z');

    expect(sessions, hasLength(1));
    expect(sessions.single.deviceId, 'installation-1');
    expect(sessions.single.scopes, ['devices:read', 'devices:write']);
    expect(sessions.single.current, isTrue);
  });

  test('device list parser rejects missing list contract', () {
    expect(
      () => parseCloudDeviceList(const {}),
      throwsFormatException,
    );
  });

  test('Cloud client uses Auth v1 device and session endpoints', () async {
    final transport = _FakeTransport();
    final client = LifeTraceCloudClient(transport: transport);

    transport.next = {
      'devices': [
        _deviceJson(
          id: 'installation-1',
          name: 'Pixel',
          current: true,
        ),
      ],
    };
    final devices = await client.listDevices(
      baseUrl: 'https://cloud.example.com',
      accessToken: 'token',
    );
    expect(devices.single.id, 'installation-1');
    expect(transport.lastMethod, 'GET');
    expect(transport.lastPath, '/api/v1/auth/devices');

    transport.next = _deviceJson(
      id: 'installation-1',
      name: 'Renamed',
      current: true,
    );
    final renamed = await client.updateDevice(
      baseUrl: 'https://cloud.example.com',
      accessToken: 'token',
      deviceId: 'installation-1',
      deviceName: '  Renamed  ',
    );
    expect(renamed.deviceName, 'Renamed');
    expect(transport.lastMethod, 'PATCH');
    expect(transport.lastPath, '/api/v1/auth/devices/installation-1');
    expect(transport.lastBody, {'deviceName': 'Renamed'});

    transport.next = const {};
    await client.revokeDevice(
      baseUrl: 'https://cloud.example.com',
      accessToken: 'token',
      deviceId: 'installation-2',
    );
    expect(transport.lastMethod, 'POST');
    expect(
      transport.lastPath,
      '/api/v1/auth/devices/installation-2/revoke',
    );

    transport.next = {
      'sessions': [
        _sessionJson(
          id: 'session-2',
          deviceId: 'installation-2',
          current: false,
        ),
      ],
    };
    final sessions = await client.listSessions(
      baseUrl: 'https://cloud.example.com',
      accessToken: 'token',
    );
    expect(sessions.single.id, 'session-2');
    expect(transport.lastMethod, 'GET');
    expect(transport.lastPath, '/api/v1/auth/sessions');

    transport.next = const {};
    await client.revokeSession(
      baseUrl: 'https://cloud.example.com',
      accessToken: 'token',
      sessionId: 'session-2',
    );
    expect(transport.lastMethod, 'DELETE');
    expect(transport.lastPath, '/api/v1/auth/sessions/session-2');
  });

  test('rename rejects blank device name before transport', () async {
    final transport = _FakeTransport();
    final client = LifeTraceCloudClient(transport: transport);

    await expectLater(
      client.updateDevice(
        baseUrl: 'https://cloud.example.com',
        accessToken: 'token',
        deviceId: 'installation-1',
        deviceName: '   ',
      ),
      throwsArgumentError,
    );
    expect(transport.calls, 0);
  });
}

Map<String, dynamic> _deviceJson({
  required String id,
  required String name,
  required bool current,
}) =>
    {
      'id': id,
      'externalDeviceId': 'external-$id',
      'deviceGroupId': 'group-1',
      'deviceName': name,
      'appId': 'lifetrace-execute-android',
      'platform': 'android',
      'status': 'active',
      'clientVersion': '1.0.0',
      'firstSeenAt': '2026-09-01T00:00:00Z',
      'lastSeenAt': '2026-09-16T02:10:00Z',
      'lastLoginAt': '2026-09-16T01:00:00Z',
      'lastSyncAt': '2026-09-16T02:00:00Z',
      'revokedAt': null,
      'current': current,
    };

Map<String, dynamic> _sessionJson({
  required String id,
  required String deviceId,
  required bool current,
}) =>
    {
      'id': id,
      'appId': 'lifetrace-execute-android',
      'deviceId': deviceId,
      'sessionType': 'refresh',
      'status': 'active',
      'scopes': ['devices:read', 'devices:write'],
      'publicDevice': false,
      'createdAt': '2026-09-16T01:00:00Z',
      'lastSeenAt': '2026-09-16T02:10:00Z',
      'idleExpiresAt': '2026-10-16T02:10:00Z',
      'absoluteExpiresAt': '2026-12-16T02:10:00Z',
      'revokedAt': null,
      'current': current,
    };

class _FakeTransport extends CloudHttpTransport {
  Map<String, dynamic> next = const {};
  String? lastMethod;
  String? lastPath;
  Map<String, dynamic>? lastBody;
  String? lastAccessToken;
  int calls = 0;

  @override
  Future<Map<String, dynamic>> requestJson({
    required String method,
    required String baseUrl,
    required String path,
    Map<String, dynamic>? body,
    String? accessToken,
  }) async {
    calls++;
    lastMethod = method;
    lastPath = path;
    lastBody = body;
    lastAccessToken = accessToken;
    return next;
  }
}
