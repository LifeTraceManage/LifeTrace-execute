import 'dart:async';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/core/cloud/cloud_contract.dart';
import 'package:lifetrace_execute/core/cloud/cloud_session_manager.dart';
import 'package:lifetrace_execute/core/cloud/lifetrace_sync_client.dart';
import 'package:lifetrace_execute/core/cloud/secure_session_store.dart';
import 'package:lifetrace_execute/core/cloud/sync_models.dart';
import 'package:lifetrace_execute/data/local/app_database.dart';
import 'package:lifetrace_execute/data/repository/task_repository.dart';
import 'package:lifetrace_execute/data/sync/task_sync_coordinator.dart';
import 'package:lifetrace_execute/domain/task/execution_task.dart';

void main() {
  late AppDatabase database;
  late DriftTaskRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftTaskRepository(database);
  });

  tearDown(() => database.close());

  test('snapshot bootstrap and pull apply upsert and tombstone', () async {
    final client = _FakeSyncClient(
      snapshots: [
        SnapshotPageResult(
          requestId: 'snapshot-request',
          snapshotId: 'snapshot-1',
          snapshotCursor: '10',
          items: [
            SnapshotItem(
              entityType: DriftTaskRepository.entityType,
              entityId: 'remote-1',
              serverVersion: '5',
              payload: _payload('remote-1', 'From snapshot'),
            ),
          ],
          completed: true,
          serverTime: '2026-09-11T00:00:00.000Z',
        ),
      ],
      pulls: [
        PullBatchResult(
          requestId: 'pull-1',
          serverTime: '2026-09-11T00:01:00.000Z',
          changes: [
            PulledChange(
              cursor: '11',
              entityType: DriftTaskRepository.entityType,
              entityId: 'remote-2',
              operation: 'upsert',
              serverVersion: '1',
              serverModifiedAt: '2026-09-11T00:01:00.000Z',
              payload: _payload('remote-2', 'From pull'),
            ),
            const PulledChange(
              cursor: '12',
              entityType: DriftTaskRepository.entityType,
              entityId: 'remote-1',
              operation: 'delete',
              serverVersion: '6',
              serverModifiedAt: '2026-09-11T00:01:01.000Z',
              tombstone: {'deletedAt': '2026-09-11T00:01:01.000Z'},
            ),
          ],
          nextCursor: '12',
          hasMore: false,
        ),
      ],
    );

    final summary = await _coordinator(client).syncNow();

    expect(summary.snapshotItems, 1);
    expect(summary.pulled, 2);
    final tasks = await database.select(database.tasks).get();
    expect(tasks, hasLength(1));
    expect(tasks.single.id, 'remote-2');
    expect(tasks.single.title, 'From pull');
    final state = (await database.select(database.syncState).get()).single;
    expect(state.cursor, '12');
  });

  test('accepted push rebases the next unattempted local change', () async {
    final created = await repository.createTask(
      userId: 'user-1',
      deviceId: 'device-1',
      title: 'First version',
    );
    await repository.updateTask(
      task: created,
      deviceId: 'device-1',
      title: 'Second version',
    );

    final client = _FakeSyncClient(
      snapshots: [_emptySnapshot()],
      pulls: [_emptyPull('22')],
      acceptAllPushes: true,
    );

    final summary = await _coordinator(client).syncNow();

    expect(summary.pushed, 2);
    expect(client.pushBatches, hasLength(2));
    expect(client.pushBatches.first.single.baseServerVersion, '0');
    expect(client.pushBatches[1].single.baseServerVersion, '101');
    expect(client.pushBatches[1].single.payload?['title'], 'Second version');
    expect(await database.select(database.syncOutbox).get(), isEmpty);
    final task = (await database.select(database.tasks).get()).single;
    expect(task.serverVersion, '102');
  });

  test('conflict persists record and blocks all queued changes for entity', () async {
    final created = await repository.createTask(
      userId: 'user-1',
      deviceId: 'device-1',
      title: 'Local one',
    );
    await repository.updateTask(
      task: created,
      deviceId: 'device-1',
      title: 'Local two',
    );

    final client = _FakeSyncClient(
      snapshots: [_emptySnapshot()],
      pulls: [_emptyPull('31')],
      pushHandler: (changes) => PushBatchResult(
        requestId: 'push-conflict',
        serverTime: '2026-09-11T00:02:00.000Z',
        latestCursor: '30',
        results: [
          PushConflict(
            changeId: changes.single.changeId,
            entityType: DriftTaskRepository.entityType,
            entityId: created.id,
            conflictId: 'conflict-1',
            clientBaseServerVersion: '0',
            currentServerVersion: '9',
            serverDeleted: false,
            serverEntity: _payload(created.id, 'Cloud title'),
            reason: 'server version changed',
          ),
        ],
      ),
    );

    final summary = await _coordinator(client).syncNow();

    expect(summary.conflicts, 1);
    final conflicts = await database.select(database.syncConflicts).get();
    expect(conflicts, hasLength(1));
    expect(conflicts.single.id, 'conflict-1');
    expect(conflicts.single.serverVersion, '9');
    final outbox = await database.select(database.syncOutbox).get();
    expect(outbox, hasLength(2));
    expect(outbox.every((item) => item.blocked), isTrue);
    expect(outbox.every((item) => item.errorCode == 'SYNC_CONFLICT'), isTrue);
  });

  test('rejected push is retained and blocked with server error', () async {
    final created = await repository.createTask(
      userId: 'user-1',
      deviceId: 'device-1',
      title: 'Will reject',
    );
    final client = _FakeSyncClient(
      snapshots: [_emptySnapshot()],
      pulls: [_emptyPull('41')],
      pushHandler: (changes) => PushBatchResult(
        requestId: 'push-rejected',
        serverTime: '2026-09-11T00:03:00.000Z',
        latestCursor: '40',
        results: [
          PushRejected(
            changeId: changes.single.changeId,
            entityType: DriftTaskRepository.entityType,
            entityId: created.id,
            code: 'INVALID_ENTITY',
            message: 'bad task',
          ),
        ],
      ),
    );

    final summary = await _coordinator(client).syncNow();

    expect(summary.rejected, 1);
    final row = (await database.select(database.syncOutbox).get()).single;
    expect(row.blocked, isTrue);
    expect(row.errorCode, 'INVALID_ENTITY');
    expect(row.errorMessage, 'bad task');
  });

  test('transport failure keeps local change and records retryable failure', () async {
    await repository.createTask(
      userId: 'user-1',
      deviceId: 'device-1',
      title: 'Offline safe',
    );
    final client = _FakeSyncClient(
      snapshots: [_emptySnapshot()],
      pulls: [_emptyPull('51')],
      pushError: const CloudApiException(
        statusCode: 503,
        code: 'TEMPORARY',
        retryable: true,
        message: 'temporary outage',
      ),
    );

    await expectLater(_coordinator(client).syncNow(), throwsA(isA<CloudApiException>()));

    expect(await database.select(database.tasks).get(), hasLength(1));
    final row = (await database.select(database.syncOutbox).get()).single;
    expect(row.attemptCount, 1);
    expect(row.blocked, isFalse);
    expect(row.errorCode, 'TEMPORARY');
  });

  test('pull does not overwrite an entity that still has local outbox', () async {
    final created = await repository.createTask(
      userId: 'user-1',
      deviceId: 'device-1',
      title: 'Keep local',
    );
    await database.into(database.syncState).insert(
          SyncStateCompanion.insert(
            scope: TaskSyncCoordinator.taskScopeKey,
            userId: 'user-1',
            cursor: const Value('60'),
            updatedAt: '2026-09-11T00:04:00.000Z',
          ),
        );
    await (database.update(database.syncOutbox)
          ..where((table) => table.entityId.equals(created.id)))
        .write(const SyncOutboxCompanion(blocked: Value(true)));

    final client = _FakeSyncClient(
      pulls: [
        PullBatchResult(
          requestId: 'pull-local',
          serverTime: '2026-09-11T00:05:00.000Z',
          changes: [
            PulledChange(
              cursor: '61',
              entityType: DriftTaskRepository.entityType,
              entityId: created.id,
              operation: 'upsert',
              serverVersion: '77',
              serverModifiedAt: '2026-09-11T00:05:00.000Z',
              payload: _payload(created.id, 'Remote overwrite'),
            ),
          ],
          nextCursor: '61',
          hasMore: false,
        ),
      ],
    );

    await _coordinator(client).syncNow();

    final task = (await database.select(database.tasks).get()).single;
    expect(task.title, 'Keep local');
    expect(task.serverVersion, isNull);
  });

  test('concurrent syncNow calls share one in-flight operation', () async {
    final gate = Completer<void>();
    final client = _FakeSyncClient(
      snapshots: [_emptySnapshot()],
      pulls: [_emptyPull('71')],
      snapshotGate: gate,
    );
    final coordinator = _coordinator(client);

    final first = coordinator.syncNow();
    final second = coordinator.syncNow();
    expect(identical(first, second), isTrue);
    gate.complete();
    await Future.wait([first, second]);
    expect(client.snapshotCalls, 1);
  });

  TaskSyncCoordinator _coordinator(_FakeSyncClient client) => TaskSyncCoordinator(
        database: database,
        sessionManager: _FakeSessionAccess(_session()),
        syncClient: client,
        deviceIdLoader: () async => 'device-1',
        clientVersion: 'test',
      );
}

StoredCloudSession _session() => const StoredCloudSession(
      baseUrl: 'https://cloud.example.com',
      accessToken: 'token',
      accessTokenExpiresAtEpochSeconds: 9999999999,
      userId: 'user-1',
      email: 'user@example.com',
      sessionId: 'session-1',
      scopes: ['sync:read', 'sync:write'],
      protocolVersion: 1,
      schemaVersion: 1,
    );

Map<String, dynamic> _payload(String id, String title) => {
      'meta': {
        'id': id,
        'userId': 'user-1',
        'createdAt': '2026-09-10T00:00:00.000Z',
        'updatedAt': '2026-09-11T00:00:00.000Z',
        'deletedAt': null,
        'localVersion': 1,
        'serverVersion': null,
        'modifiedByDevice': 'remote-device',
      },
      'title': title,
      'description': null,
      'projectId': null,
      'status': ExecutionTaskStatus.todo.wireValue,
      'priority': ExecutionTaskPriority.normal.wireValue,
      'dueAt': null,
      'scheduledAt': null,
      'completedAt': null,
    };

SnapshotPageResult _emptySnapshot() => const SnapshotPageResult(
      requestId: 'snapshot-empty',
      snapshotId: 'snapshot-empty',
      snapshotCursor: '20',
      items: [],
      completed: true,
      serverTime: '2026-09-11T00:00:00.000Z',
    );

PullBatchResult _emptyPull(String cursor) => PullBatchResult(
      requestId: 'pull-empty-$cursor',
      serverTime: '2026-09-11T00:10:00.000Z',
      changes: const [],
      nextCursor: cursor,
      hasMore: false,
    );

class _FakeSessionAccess implements CloudSessionAccess {
  _FakeSessionAccess(this.session);
  final StoredCloudSession session;

  @override
  Future<StoredCloudSession?> currentSession() async => session;

  @override
  Future<T> authorized<T>(Future<T> Function(StoredCloudSession session) block) =>
      block(session);
}

class _FakeSyncClient implements SyncClient {
  _FakeSyncClient({
    this.snapshots = const [],
    this.pulls = const [],
    this.pushHandler,
    this.pushError,
    this.acceptAllPushes = false,
    this.snapshotGate,
  });

  final List<SnapshotPageResult> snapshots;
  final List<PullBatchResult> pulls;
  final PushBatchResult Function(List<OutgoingSyncChange>)? pushHandler;
  final Object? pushError;
  final bool acceptAllPushes;
  final Completer<void>? snapshotGate;
  final List<List<OutgoingSyncChange>> pushBatches = [];
  int snapshotCalls = 0;
  int _snapshotIndex = 0;
  int _pullIndex = 0;
  int _acceptedVersion = 100;

  @override
  Future<PushBatchResult> push({
    required String baseUrl,
    required String accessToken,
    required SyncClientContext client,
    required List<OutgoingSyncChange> changes,
  }) async {
    pushBatches.add(List.unmodifiable(changes));
    if (pushError != null) throw pushError!;
    final handler = pushHandler;
    if (handler != null) return handler(changes);
    if (!acceptAllPushes) {
      return PushBatchResult(
        requestId: 'push-empty',
        serverTime: '2026-09-11T00:00:00.000Z',
        latestCursor: '0',
        results: const [],
      );
    }
    final results = <PushChangeResult>[];
    for (final change in changes) {
      _acceptedVersion++;
      results.add(
        PushAccepted(
          changeId: change.changeId,
          entityType: change.entityType,
          entityId: change.entityId,
          serverVersion: '$_acceptedVersion',
          cursor: '$_acceptedVersion',
          serverModifiedAt: '2026-09-11T00:00:00.000Z',
          duplicate: false,
        ),
      );
    }
    return PushBatchResult(
      requestId: 'push-accepted',
      serverTime: '2026-09-11T00:00:00.000Z',
      latestCursor: '$_acceptedVersion',
      results: results,
    );
  }

  @override
  Future<PullBatchResult> pull({
    required String baseUrl,
    required String accessToken,
    required SyncClientContext client,
    required String? afterCursor,
    int limit = 100,
    List<String>? entityTypes,
  }) async {
    if (_pullIndex >= pulls.length) return _emptyPull(afterCursor ?? '0');
    return pulls[_pullIndex++];
  }

  @override
  Future<SnapshotPageResult> snapshot({
    required String baseUrl,
    required String accessToken,
    required SyncClientContext client,
    String? snapshotId,
    String? pageToken,
    List<String>? entityTypes,
    int pageSize = 200,
  }) async {
    snapshotCalls++;
    if (snapshotGate != null) await snapshotGate!.future;
    if (_snapshotIndex >= snapshots.length) return _emptySnapshot();
    return snapshots[_snapshotIndex++];
  }
}
