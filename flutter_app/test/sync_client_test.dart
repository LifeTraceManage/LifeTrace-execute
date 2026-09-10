import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/core/cloud/cloud_http_transport.dart';
import 'package:lifetrace_execute/core/cloud/lifetrace_sync_client.dart';
import 'package:lifetrace_execute/core/cloud/sync_models.dart';

class _RecordingTransport extends CloudHttpTransport {
  Map<String, dynamic>? lastBody;

  @override
  Future<Map<String, dynamic>> requestJson({
    required String method,
    required String baseUrl,
    required String path,
    Map<String, dynamic>? body,
    String? accessToken,
  }) async {
    lastBody = body;
    return {
      'requestId': 'request-1',
      'serverTime': '2026-09-10T00:00:00Z',
      'latestCursor': 'cursor-1',
      'results': [
        {
          'status': 'accepted',
          'changeId': 'change-1',
          'entityType': 'execution.task',
          'entityId': 'task-1',
          'serverVersion': '1',
          'cursor': 'cursor-1',
          'serverModifiedAt': '2026-09-10T00:00:00Z',
        },
      ],
    };
  }
}

void main() {
  test('push serializes LifeTrace Sync v1 client and change payload', () async {
    final transport = _RecordingTransport();
    final client = LifeTraceSyncClient(transport: transport);

    final result = await client.push(
      baseUrl: 'https://cloud.example.com',
      accessToken: 'token',
      client: const SyncClientContext(
        clientVersion: '0.3.0',
        deviceId: 'device-1',
        schemaVersion: 1,
      ),
      changes: const [
        OutgoingSyncChange(
          changeId: 'change-1',
          entityType: 'execution.task',
          entityId: 'task-1',
          operation: 'upsert',
          baseServerVersion: '0',
          clientModifiedAt: '2026-09-10T00:00:00Z',
          payload: {
            'meta': {'id': 'task-1', 'schemaVersion': 1},
            'title': 'Task',
          },
        ),
      ],
    );

    final body = transport.lastBody!;
    final context = body['client'] as Map<String, dynamic>;
    expect(context['appId'], 'lifetrace-execute-android');
    expect(context['platform'], 'android');
    expect(context['deviceId'], 'device-1');

    final changes = body['changes'] as List<dynamic>;
    final change = changes.single as Map<String, dynamic>;
    expect(change['operation'], 'upsert');
    expect(change['payload'], isA<Map<String, dynamic>>());
    expect(result.results.single, isA<PushAccepted>());
  });

  test('delete rejects accidental payload', () async {
    final client = LifeTraceSyncClient(transport: _RecordingTransport());
    expect(
      () => client.push(
        baseUrl: 'https://cloud.example.com',
        accessToken: 'token',
        client: const SyncClientContext(
          clientVersion: '0.3.0',
          deviceId: 'device-1',
          schemaVersion: 1,
        ),
        changes: const [
          OutgoingSyncChange(
            changeId: 'change-1',
            entityType: 'execution.task',
            entityId: 'task-1',
            operation: 'delete',
            baseServerVersion: '1',
            clientModifiedAt: '2026-09-10T00:00:00Z',
            payload: {'unexpected': true},
          ),
        ],
      ),
      throwsArgumentError,
    );
  });
}
