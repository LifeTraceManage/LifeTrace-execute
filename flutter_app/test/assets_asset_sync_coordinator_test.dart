import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/workspaces/assets/src/cloud/asset_sync_coordinator.dart';
import 'package:lifetrace_execute/workspaces/assets/src/cloud/cloud_session_manager.dart';
import 'package:lifetrace_execute/workspaces/assets/src/cloud/secure_session_store.dart';
import 'package:lifetrace_execute/workspaces/assets/src/cloud/sync_models.dart';
import 'package:lifetrace_execute/workspaces/assets/src/cloud/lifetrace_sync_client.dart';
import 'package:lifetrace_execute/workspaces/assets/src/data/asset_repository.dart';
import 'package:lifetrace_execute/workspaces/assets/src/domain/asset_models.dart';

class _FakeSessionAccess implements CloudSessionAccess {
  _FakeSessionAccess({
    List<String> scopes = const [
      'sync:read',
      'sync:write',
      'assets:read',
      'assets:write',
      'links:read',
      'links:write',
    ],
  }) : session = StoredCloudSession(
          baseUrl: 'https://cloud.example.com',
          accessToken: 'token',
          accessTokenExpiresAtEpochSeconds: 4102444800,
          userId: 'user-1',
          email: 'user@example.com',
          sessionId: 'session-1',
          scopes: scopes,
          schemaVersion: 1,
        );

  final StoredCloudSession session;

  @override
  Future<T> authorized<T>(
    Future<T> Function(StoredCloudSession session) block,
  ) =>
      block(session);

  @override
  Future<StoredCloudSession?> currentSession() async => session;

  @override
  Future<StoredCloudSession> login({
    required String baseUrl,
    required String email,
    required String password,
  }) async =>
      session;

  @override
  Future<void> logout() async {}
}

class _FakeSyncClient implements SyncClient {
  _FakeSyncClient({
    this.conflict = false,
    this.snapshotItems = const [],
    this.pullChanges = const [],
  });

  final bool conflict;
  final List<SnapshotItem> snapshotItems;
  final List<PulledChange> pullChanges;
  int pushCalls = 0;
  int snapshotCalls = 0;
  int pullCalls = 0;
  Set<String>? lastSnapshotEntityTypes;
  Set<String>? lastPushEntityTypes;
  Set<String>? lastPullEntityTypes;

  @override
  Future<SnapshotPageResult> snapshot({
    required String baseUrl,
    required String accessToken,
    required SyncClientContext client,
    String? snapshotId,
    String? pageToken,
    int pageSize = 200,
  }) async {
    snapshotCalls++;
    lastSnapshotEntityTypes = Set<String>.from(client.entityTypes);
    return SnapshotPageResult(
      snapshotId: 'snapshot-1',
      snapshotCursor: 'cursor-snapshot',
      items: snapshotItems,
      completed: true,
    );
  }

  @override
  Future<PushBatchResult> push({
    required String baseUrl,
    required String accessToken,
    required SyncClientContext client,
    required List<OutgoingSyncChange> changes,
  }) async {
    pushCalls++;
    lastPushEntityTypes = Set<String>.from(client.entityTypes);
    final change = changes.single;
    if (conflict) {
      return PushBatchResult(
        latestCursor: 'cursor-conflict',
        results: [
          PushConflict(
            changeId: change.changeId,
            entityType: change.entityType,
            entityId: change.entityId,
            conflictId: 'conflict-1',
            clientBaseServerVersion: change.baseServerVersion,
            currentServerVersion: '4',
            serverDeleted: false,
            reason: 'version_mismatch',
            serverEntity: {
              ...?change.payload,
              'currentValue': 650.0,
              'serverVersion': '4',
            },
          ),
        ],
      );
    }
    return PushBatchResult(
      latestCursor: 'cursor-push',
      results: [
        PushAccepted(
          changeId: change.changeId,
          entityType: change.entityType,
          entityId: change.entityId,
          serverVersion: '1',
          cursor: 'cursor-push',
          serverModifiedAt: '2026-09-11T00:00:00Z',
          duplicate: false,
        ),
      ],
    );
  }

  @override
  Future<PullBatchResult> pull({
    required String baseUrl,
    required String accessToken,
    required SyncClientContext client,
    required String? afterCursor,
    int limit = 100,
  }) async {
    pullCalls++;
    lastPullEntityTypes = Set<String>.from(client.entityTypes);
    return PullBatchResult(
      changes: pullChanges,
      nextCursor: 'cursor-pull',
      hasMore: false,
    );
  }
}

AssetItem _asset() {
  final now = DateTime(2026, 9, 11);
  return AssetItem(
    id: 'asset-1',
    name: 'Phone',
    brand: 'LifeTrace',
    model: 'V1',
    category: AssetCategory.phone,
    status: AssetStatus.active,
    purchasePrice: 1000,
    currentValue: 800,
    purchaseDate: DateTime(2026, 1, 1),
    warrantyUntil: DateTime(2027, 1, 1),
    spec: '',
    serialNumber: '',
    location: '',
    targetDailyCost: 0,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  test('coordinator performs snapshot push and pull and acknowledges local change',
      () async {
    final repository =
        await AssetRepository.inMemory('sync-coordinator-accepted.db');
    await repository.clearAll();
    await repository.upsertAsset(_asset());

    final syncClient = _FakeSyncClient();
    final coordinator = AssetSyncCoordinator(
      repository: repository,
      sessionManager: _FakeSessionAccess(),
      syncClient: syncClient,
      deviceIdLoader: () async => 'device-1',
    );

    final summary = await coordinator.syncNow();

    expect(syncClient.snapshotCalls, 1);
    expect(syncClient.pushCalls, 1);
    expect(syncClient.pullCalls, 1);
    expect(summary.snapshotItems, 0);
    expect(summary.pushed, 1);
    expect(summary.pulled, 0);
    expect(summary.conflicts, 0);
    expect(await repository.pendingOutboxCount(), 0);
    expect((await repository.listAssets()).single.serverVersion, '1');
    expect((await repository.getSyncState()).cursor, 'cursor-pull');

    await repository.close();
  });

  test('coordinator restores asset EntityLink from snapshot', () async {
    final repository =
        await AssetRepository.inMemory('sync-coordinator-link.db');
    await repository.clearAll();

    final asset = _asset();
    final now = DateTime(2026, 9, 11);
    final link = AssetEntityLink(
      id: 'link-remote',
      userId: 'user-1',
      sourceAssetId: asset.id,
      targetEntityType: 'execution.project',
      targetEntityId: 'project-remote',
      relationType: 'references',
      targetLabel: 'Remote Project',
      createdAt: now,
      updatedAt: now,
      serverVersion: '5',
    );
    final syncClient = _FakeSyncClient(
      snapshotItems: [
        SnapshotItem(
          entityType: 'asset.asset',
          entityId: asset.id,
          serverVersion: '3',
          payload: Map<String, dynamic>.from(asset.toJson()),
        ),
        SnapshotItem(
          entityType: 'entity.link',
          entityId: link.id,
          serverVersion: '5',
          payload: Map<String, dynamic>.from(link.toCloudJson()),
        ),
      ],
    );
    final coordinator = AssetSyncCoordinator(
      repository: repository,
      sessionManager: _FakeSessionAccess(),
      syncClient: syncClient,
      deviceIdLoader: () async => 'device-1',
    );

    final summary = await coordinator.syncNow();

    expect(summary.snapshotItems, 2);
    expect(await repository.listAssets(), hasLength(1));
    final links = await repository.listLinks(sourceAssetId: asset.id);
    expect(links, hasLength(1));
    expect(links.single.id, 'link-remote');
    expect(links.single.targetEntityId, 'project-remote');
    expect(links.single.serverVersion, '5');

    await repository.close();
  });

  test('coordinator pulls EntityLink incrementally after an existing cursor',
      () async {
    final repository =
        await AssetRepository.inMemory('sync-coordinator-link-pull.db');
    await repository.clearAll();

    final asset = _asset();
    await repository.applyRemoteChange(
      entityType: 'asset.asset',
      entityId: asset.id,
      operation: 'upsert',
      serverVersion: '3',
      payload: asset.toJson(),
    );
    await repository.setSyncCursor('cursor-before');

    final now = DateTime(2026, 9, 11);
    final link = AssetEntityLink(
      id: 'link-pulled',
      userId: 'user-1',
      sourceAssetId: asset.id,
      targetEntityType: 'execution.task',
      targetEntityId: 'task-remote',
      relationType: 'references',
      targetLabel: 'Remote Task',
      createdAt: now,
      updatedAt: now,
      serverVersion: '7',
    );
    final syncClient = _FakeSyncClient(
      pullChanges: [
        PulledChange(
          cursor: 'cursor-link',
          entityType: 'entity.link',
          entityId: link.id,
          operation: 'upsert',
          serverVersion: '7',
          serverModifiedAt: '2026-09-11T00:00:00Z',
          payload: Map<String, dynamic>.from(link.toCloudJson()),
        ),
      ],
    );
    final coordinator = AssetSyncCoordinator(
      repository: repository,
      sessionManager: _FakeSessionAccess(),
      syncClient: syncClient,
      deviceIdLoader: () async => 'device-1',
    );

    final summary = await coordinator.syncNow();

    expect(syncClient.snapshotCalls, 0);
    expect(syncClient.pushCalls, 0);
    expect(syncClient.pullCalls, 1);
    expect(summary.pulled, 1);
    final links = await repository.listLinks(sourceAssetId: asset.id);
    expect(links, hasLength(1));
    expect(links.single.id, 'link-pulled');
    expect(links.single.targetEntityType, 'execution.task');
    expect(links.single.serverVersion, '7');
    expect((await repository.getSyncState()).cursor, 'cursor-pull');

    await repository.close();
  });

  test('legacy session without link scopes keeps EntityLink pending while core sync continues',
      () async {
    final repository =
        await AssetRepository.inMemory('sync-coordinator-legacy-scopes.db');
    await repository.clearAll();
    await repository.upsertAsset(_asset());

    final now = DateTime(2026, 9, 11);
    await repository.upsertLink(
      AssetEntityLink(
        id: 'link-pending-scope',
        userId: 'user-1',
        sourceAssetId: 'asset-1',
        targetEntityType: 'execution.project',
        targetEntityId: 'project-legacy',
        relationType: 'references',
        targetLabel: 'Legacy Session Project',
        createdAt: now,
        updatedAt: now,
      ),
    );

    final syncClient = _FakeSyncClient();
    final coordinator = AssetSyncCoordinator(
      repository: repository,
      sessionManager: _FakeSessionAccess(
        scopes: const [
          'sync:read',
          'sync:write',
          'assets:read',
          'assets:write',
        ],
      ),
      syncClient: syncClient,
      deviceIdLoader: () async => 'device-legacy',
    );

    final summary = await coordinator.syncNow();

    expect(summary.pushed, 1);
    expect(syncClient.pushCalls, 1);
    expect(syncClient.snapshotCalls, 1);
    expect(syncClient.pullCalls, 1);
    expect(
      syncClient.lastSnapshotEntityTypes,
      {'asset.asset', 'asset.event'},
    );
    expect(
      syncClient.lastPullEntityTypes,
      {'asset.asset', 'asset.event'},
    );
    expect(
      syncClient.lastPushEntityTypes,
      {'asset.asset', 'asset.event'},
    );

    final remaining = await repository.listOutbox();
    expect(remaining, hasLength(1));
    expect(remaining.single['entityType'], 'entity.link');
    expect(remaining.single['blocked'], isFalse);

    await repository.close();
  });

  test('coordinator persists optimistic conflict without losing local intent',
      () async {
    final repository =
        await AssetRepository.inMemory('sync-coordinator-conflict.db');
    await repository.clearAll();
    await repository.upsertAsset(_asset());

    final syncClient = _FakeSyncClient(conflict: true);
    final coordinator = AssetSyncCoordinator(
      repository: repository,
      sessionManager: _FakeSessionAccess(),
      syncClient: syncClient,
      deviceIdLoader: () async => 'device-1',
    );

    final summary = await coordinator.syncNow();

    expect(summary.conflicts, 1);
    expect(syncClient.pushCalls, 1);
    expect(await repository.listConflicts(), hasLength(1));
    expect(await repository.listSyncIssues(), isEmpty);
    final outbox = await repository.listOutbox();
    expect(outbox, hasLength(1));
    expect(outbox.single['blocked'], isTrue);
    expect(outbox.single['payload'], isNotNull);

    await repository.close();
  });
}
