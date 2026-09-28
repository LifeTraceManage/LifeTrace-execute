import '../data/asset_repository.dart';
import '../domain/asset_models.dart';
import 'cloud_contract.dart';
import 'cloud_session_manager.dart';
import 'device_identity_store.dart';
import 'lifetrace_sync_client.dart';
import 'sync_models.dart';

class AssetSyncSummary {
  const AssetSyncSummary({
    required this.snapshotItems,
    required this.pushed,
    required this.pulled,
    required this.conflicts,
    required this.rejected,
  });

  final int snapshotItems;
  final int pushed;
  final int pulled;
  final int conflicts;
  final int rejected;
}

class AssetSyncCoordinator {
  AssetSyncCoordinator({
    required this.repository,
    required this.sessionManager,
    SyncClient? syncClient,
    Future<String> Function()? deviceIdLoader,
    DeviceIdentityStore? identityStore,
  })  : _syncClient = syncClient ?? LifeTraceSyncClient(),
        _deviceIdLoader = deviceIdLoader ??
            (identityStore ?? DeviceIdentityStore()).getOrCreate;

  static const _pushBatchSize = 100;
  static const _pullBatchSize = 100;
  static const _snapshotPageSize = 100;
  static const _maxPushRounds = 50;

  final AssetRepository repository;
  final CloudSessionAccess sessionManager;
  final SyncClient _syncClient;
  final Future<String> Function() _deviceIdLoader;

  Future<AssetSyncSummary>? _activeSync;

  Future<AssetSyncSummary> syncNow() {
    final active = _activeSync;
    if (active != null) return active;

    late final Future<AssetSyncSummary> tracked;
    tracked = _syncInternal().whenComplete(() {
      if (identical(_activeSync, tracked)) _activeSync = null;
    });
    _activeSync = tracked;
    return tracked;
  }

  Future<AssetSyncSummary> _syncInternal() {
    return sessionManager.authorized((session) async {
      await repository.bindCloudUser(session.userId);
      final readableEntityTypes =
          CloudContract.readableSyncEntityTypes(session.scopes);
      final writableEntityTypes =
          CloudContract.writableSyncEntityTypes(session.scopes);
      final client = SyncClientContext(
        clientVersion: CloudContract.clientVersion,
        deviceId: await _deviceIdLoader(),
        schemaVersion: session.schemaVersion,
        entityTypes: readableEntityTypes,
      );

      var snapshotItems = 0;
      var pushed = 0;
      var conflicts = 0;
      var rejected = 0;

      var state = await repository.getSyncState();
      if (state.cursor == null) {
        snapshotItems = await _restoreSnapshot(
          baseUrl: session.baseUrl,
          accessToken: session.accessToken,
          client: client,
        );
        state = await repository.getSyncState();
      }

      for (var round = 0; round < _maxPushRounds; round++) {
        final result = await _pushOneRound(
          baseUrl: session.baseUrl,
          accessToken: session.accessToken,
          client: client,
          writableEntityTypes: writableEntityTypes,
        );
        if (!result.hadWork) break;
        pushed += result.accepted;
        conflicts += result.conflicts;
        rejected += result.rejected;
      }

      final pulled = await _pullUntilCurrent(
        baseUrl: session.baseUrl,
        accessToken: session.accessToken,
        client: client,
        afterCursor: state.cursor,
      );

      return AssetSyncSummary(
        snapshotItems: snapshotItems,
        pushed: pushed,
        pulled: pulled,
        conflicts: conflicts,
        rejected: rejected,
      );
    });
  }

  Future<int> _restoreSnapshot({
    required String baseUrl,
    required String accessToken,
    required SyncClientContext client,
  }) async {
    var state = await repository.getSyncState();
    var snapshotId = state.snapshotId;
    var pageToken = state.snapshotPageToken;
    var total = 0;

    while (true) {
      final page = await _syncClient.snapshot(
        baseUrl: baseUrl,
        accessToken: accessToken,
        client: client,
        snapshotId: snapshotId,
        pageToken: pageToken,
        pageSize: _snapshotPageSize,
      );

      for (final item in page.items) {
        if (!client.entityTypes.contains(item.entityType)) {
          continue;
        }
        await repository.applyRemoteChange(
          entityType: item.entityType,
          entityId: item.entityId,
          operation: 'upsert',
          serverVersion: item.serverVersion,
          payload: Map<String, Object?>.from(item.payload),
        );
      }

      await repository.saveSnapshotProgress(
        snapshotId: page.snapshotId,
        pageToken: page.nextPageToken,
        snapshotCursor: page.snapshotCursor,
        completed: page.completed,
      );

      total += page.items.length;
      if (page.completed) return total;
      if (page.nextPageToken == null || page.nextPageToken!.isEmpty) {
        throw const FormatException(
          'LifeTrace Cloud snapshot 未完成但缺少 nextPageToken',
        );
      }

      state = await repository.getSyncState();
      snapshotId = state.snapshotId ?? page.snapshotId;
      pageToken = state.snapshotPageToken ?? page.nextPageToken;
    }
  }

  Future<_PushRoundResult> _pushOneRound({
    required String baseUrl,
    required String accessToken,
    required SyncClientContext client,
    required Set<String> writableEntityTypes,
  }) async {
    final heads = await repository.listPushableOutboxHeads(
      limit: _pushBatchSize,
      entityTypes: writableEntityTypes,
    );

    if (heads.isEmpty) return const _PushRoundResult(hadWork: false);

    for (final item in heads) {
      await repository.markOutboxAttempt(item['id'].toString());
    }

    PushBatchResult response;
    try {
      response = await _syncClient.push(
        baseUrl: baseUrl,
        accessToken: accessToken,
        client: client,
        changes: heads.map((item) {
          final rawPayload = item['payload'];
          return OutgoingSyncChange(
            changeId: item['id'].toString(),
            entityType: item['entityType'].toString(),
            entityId: item['entityId'].toString(),
            operation: item['operation'].toString(),
            baseServerVersion:
                item['baseServerVersion']?.toString() ?? '0',
            clientModifiedAt: item['clientModifiedAt'].toString(),
            payload: rawPayload is Map
                ? Map<String, dynamic>.from(rawPayload)
                : null,
          );
        }).toList(growable: false),
      );
    } catch (error) {
      await repository.markOutboxTransportError(
        heads.map((item) => item['id'].toString()),
        error.toString(),
      );
      rethrow;
    }

    var accepted = 0;
    var conflicts = 0;
    var rejected = 0;

    for (final result in response.results) {
      switch (result) {
        case PushAccepted():
          accepted++;
          await repository.acknowledgeChange(
            changeId: result.changeId,
            entityType: result.entityType,
            entityId: result.entityId,
            serverVersion: result.serverVersion,
          );
        case PushConflict():
          conflicts++;
          final local = heads
              .where((item) => item['id'] == result.changeId)
              .firstOrNull;
          await repository.persistConflict(
            AssetSyncConflict(
              id: result.conflictId,
              entityType: result.entityType,
              entityId: result.entityId,
              changeId: result.changeId,
              currentServerVersion: result.currentServerVersion,
              serverDeleted: result.serverDeleted,
              reason: result.reason,
              createdAt: DateTime.now(),
              localPayload: local?['payload'] is Map
                  ? Map<String, Object?>.from(local!['payload'] as Map)
                  : null,
              serverPayload: result.serverEntity == null
                  ? null
                  : Map<String, Object?>.from(result.serverEntity!),
            ),
          );
        case PushRejected():
          rejected++;
          await repository.markOutboxRejected(
            result.changeId,
            code: result.code,
            message: result.message,
          );
      }
    }

    return _PushRoundResult(
      hadWork: true,
      accepted: accepted,
      conflicts: conflicts,
      rejected: rejected,
    );
  }

  Future<int> _pullUntilCurrent({
    required String baseUrl,
    required String accessToken,
    required SyncClientContext client,
    required String? afterCursor,
  }) async {
    var cursor = (await repository.getSyncState()).cursor ?? afterCursor;
    var total = 0;

    while (true) {
      final batch = await _syncClient.pull(
        baseUrl: baseUrl,
        accessToken: accessToken,
        client: client,
        afterCursor: cursor,
        limit: _pullBatchSize,
      );

      for (final change in batch.changes) {
        if (!client.entityTypes.contains(change.entityType)) {
          continue;
        }
        await repository.applyRemoteChange(
          entityType: change.entityType,
          entityId: change.entityId,
          operation: change.operation,
          serverVersion: change.serverVersion,
          payload: change.payload == null
              ? null
              : Map<String, Object?>.from(change.payload!),
        );
      }
      await repository.setSyncCursor(batch.nextCursor);

      total += batch.changes.length;
      if (!batch.hasMore) return total;
      if (batch.nextCursor == cursor) {
        throw const FormatException(
          'LifeTrace Cloud pull hasMore=true 但 cursor 未推进',
        );
      }
      cursor = batch.nextCursor;
    }
  }
}

class _PushRoundResult {
  const _PushRoundResult({
    required this.hadWork,
    this.accepted = 0,
    this.conflicts = 0,
    this.rejected = 0,
  });

  final bool hadWork;
  final int accepted;
  final int conflicts;
  final int rejected;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
