import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/workspaces/assets/src/cloud/cloud_http_transport.dart';
import 'package:lifetrace_execute/workspaces/assets/src/cloud/lifetrace_sync_client.dart';
import 'package:lifetrace_execute/workspaces/assets/src/cloud/sync_models.dart';

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
      'serverTime': '2026-09-11T00:00:00Z',
      'latestCursor': 'cursor-1',
      'results': [
        {
          'status': 'accepted',
          'changeId': 'change-1',
          'entityType': 'asset.asset',
          'entityId': 'asset-1',
          'serverVersion': '1',
          'cursor': 'cursor-1',
          'serverModifiedAt': '2026-09-11T00:00:00Z',
        },
      ],
    };
  }
}

const _context = SyncClientContext(
  clientVersion: '0.2.0',
  deviceId: 'device-1',
  schemaVersion: 1,
);

void main() {
  test('push serializes Assets Sync v1 client and full payload', () async {
    final transport = _RecordingTransport();
    final client = LifeTraceSyncClient(transport: transport);

    final result = await client.push(
      baseUrl: 'https://cloud.example.com',
      accessToken: 'token',
      client: _context,
      changes: const [
        OutgoingSyncChange(
          changeId: 'change-1',
          entityType: 'asset.asset',
          entityId: 'asset-1',
          operation: 'upsert',
          baseServerVersion: '0',
          clientModifiedAt: '2026-09-11T00:00:00Z',
          payload: {
            'id': 'asset-1',
            'name': 'Phone',
            'serverVersion': '0',
          },
        ),
      ],
    );

    final body = transport.lastBody!;
    final context = body['client'] as Map<String, dynamic>;
    expect(context['appId'], 'lifetrace-assets');
    expect(context['deviceId'], 'device-1');
    expect(context['protocolVersion'], 1);

    final changes = body['changes'] as List<dynamic>;
    final change = changes.single as Map<String, dynamic>;
    expect(change['entityType'], 'asset.asset');
    expect(change['baseServerVersion'], '0');
    expect(change['payload'], isA<Map<String, dynamic>>());
    expect(result.results.single, isA<PushAccepted>());
  });

  test('push accepts generic EntityLink payload for Assets', () async {
    final transport = _RecordingTransport();
    final client = LifeTraceSyncClient(transport: transport);

    await client.push(
      baseUrl: 'https://cloud.example.com',
      accessToken: 'token',
      client: _context,
      changes: const [
        OutgoingSyncChange(
          changeId: 'change-link',
          entityType: 'entity.link',
          entityId: 'link-1',
          operation: 'upsert',
          baseServerVersion: '0',
          clientModifiedAt: '2026-09-11T00:00:00Z',
          payload: {
            'meta': {
              'id': 'link-1',
              'userId': 'user-1',
              'createdAt': '2026-09-11T00:00:00Z',
              'updatedAt': '2026-09-11T00:00:00Z',
              'deletedAt': null,
              'localVersion': 1,
              'serverVersion': null,
              'modifiedByDevice': null,
            },
            'source': {
              'entityType': 'asset.asset',
              'entityId': 'asset-1',
            },
            'target': {
              'entityType': 'execution.project',
              'entityId': 'project-1',
            },
            'relationType': 'references',
            'metadata': {'label': 'Project Alpha'},
          },
        ),
      ],
    );

    final body = transport.lastBody!;
    final changes = body['changes'] as List<dynamic>;
    final change = changes.single as Map<String, dynamic>;
    expect(change['entityType'], 'entity.link');
    final payload = change['payload'] as Map<String, dynamic>;
    expect(payload['source'], isA<Map<String, dynamic>>());
    expect(payload['target'], isA<Map<String, dynamic>>());
  });

  test('delete rejects accidental payload', () {
    final client = LifeTraceSyncClient(transport: _RecordingTransport());
    expect(
      () => client.push(
        baseUrl: 'https://cloud.example.com',
        accessToken: 'token',
        client: _context,
        changes: const [
          OutgoingSyncChange(
            changeId: 'change-1',
            entityType: 'asset.asset',
            entityId: 'asset-1',
            operation: 'delete',
            baseServerVersion: '1',
            clientModifiedAt: '2026-09-11T00:00:00Z',
            payload: {'unexpected': true},
          ),
        ],
      ),
      throwsArgumentError,
    );
  });

  test('upsert requires a full payload', () {
    final client = LifeTraceSyncClient(transport: _RecordingTransport());
    expect(
      () => client.push(
        baseUrl: 'https://cloud.example.com',
        accessToken: 'token',
        client: _context,
        changes: const [
          OutgoingSyncChange(
            changeId: 'change-1',
            entityType: 'asset.event',
            entityId: 'event-1',
            operation: 'upsert',
            baseServerVersion: '0',
            clientModifiedAt: '2026-09-11T00:00:00Z',
          ),
        ],
      ),
      throwsArgumentError,
    );
  });

  test('rejects non-Assets entity type', () {
    final client = LifeTraceSyncClient(transport: _RecordingTransport());
    expect(
      () => client.push(
        baseUrl: 'https://cloud.example.com',
        accessToken: 'token',
        client: _context,
        changes: const [
          OutgoingSyncChange(
            changeId: 'change-1',
            entityType: 'execution.task',
            entityId: 'task-1',
            operation: 'delete',
            baseServerVersion: '1',
            clientModifiedAt: '2026-09-11T00:00:00Z',
          ),
        ],
      ),
      throwsArgumentError,
    );
  });
}
