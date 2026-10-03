import 'dart:convert';

import 'package:sembast/sembast_memory.dart';

import '../domain/asset_models.dart';
import 'local_database.dart';

class AssetSyncState {
  const AssetSyncState({
    this.cursor,
    this.snapshotId,
    this.snapshotPageToken,
    this.snapshotCursor,
    this.boundUserId,
  });

  final String? cursor;
  final String? snapshotId;
  final String? snapshotPageToken;
  final String? snapshotCursor;
  final String? boundUserId;

  Map<String, Object?> toJson() => {
        'cursor': cursor,
        'snapshotId': snapshotId,
        'snapshotPageToken': snapshotPageToken,
        'snapshotCursor': snapshotCursor,
        'boundUserId': boundUserId,
      };

  factory AssetSyncState.fromJson(Map<String, Object?> json) => AssetSyncState(
        cursor: json['cursor']?.toString(),
        snapshotId: json['snapshotId']?.toString(),
        snapshotPageToken: json['snapshotPageToken']?.toString(),
        snapshotCursor: json['snapshotCursor']?.toString(),
        boundUserId: json['boundUserId']?.toString(),
      );

  AssetSyncState copyWith({
    String? cursor,
    bool clearCursor = false,
    String? snapshotId,
    bool clearSnapshotId = false,
    String? snapshotPageToken,
    bool clearSnapshotPageToken = false,
    String? snapshotCursor,
    bool clearSnapshotCursor = false,
    String? boundUserId,
  }) =>
      AssetSyncState(
        cursor: clearCursor ? null : cursor ?? this.cursor,
        snapshotId:
            clearSnapshotId ? null : snapshotId ?? this.snapshotId,
        snapshotPageToken: clearSnapshotPageToken
            ? null
            : snapshotPageToken ?? this.snapshotPageToken,
        snapshotCursor: clearSnapshotCursor
            ? null
            : snapshotCursor ?? this.snapshotCursor,
        boundUserId: boundUserId ?? this.boundUserId,
      );
}

class AssetRepository {
  AssetRepository._(this._db);

  final Database _db;

  static final StoreRef<String, Map<String, Object?>> _assetStore =
      stringMapStoreFactory.store('assets');
  static final StoreRef<String, Map<String, Object?>> _eventStore =
      stringMapStoreFactory.store('asset_events');
  static final StoreRef<String, Map<String, Object?>> _linkStore =
      stringMapStoreFactory.store('entity_links');
  static final StoreRef<String, Map<String, Object?>> _outboxStore =
      stringMapStoreFactory.store('sync_outbox');
  static final StoreRef<String, Map<String, Object?>> _conflictStore =
      stringMapStoreFactory.store('sync_conflicts');
  static final StoreRef<String, Map<String, Object?>> _syncStateStore =
      stringMapStoreFactory.store('sync_state');

  static const _syncStateKey = 'assets-v1';

  static Future<AssetRepository> open() async {
    return AssetRepository._(await openAssetDatabase());
  }

  /// Creates a repository around an already-open Sembast database.
  ///
  /// Used by persistence tests and embedding environments that own the
  /// database lifecycle explicitly.
  static AssetRepository fromDatabase(Database database) =>
      AssetRepository._(database);

  static Future<AssetRepository> inMemory([
    String databaseName = 'lifetrace_assets_test.db',
  ]) async {
    return AssetRepository._(
      await databaseFactoryMemory.openDatabase(databaseName),
    );
  }

  Future<List<AssetItem>> listAssets({bool includeDeleted = false}) async {
    final records = await _assetStore.find(
      _db,
      finder: Finder(sortOrders: [SortOrder('updatedAt', false)]),
    );
    return records
        .map((record) =>
            AssetItem.fromJson(Map<String, Object?>.from(record.value)))
        .where((asset) => includeDeleted || !asset.isDeleted)
        .toList(growable: false);
  }

  Future<List<AssetEvent>> listEvents({bool includeDeleted = false}) async {
    final records = await _eventStore.find(
      _db,
      finder: Finder(sortOrders: [SortOrder('date', false)]),
    );
    return records
        .map((record) =>
            AssetEvent.fromJson(Map<String, Object?>.from(record.value)))
        .where((event) => includeDeleted || !event.isDeleted)
        .toList(growable: false);
  }

  Future<List<AssetEntityLink>> listLinks({
    bool includeDeleted = false,
    String? sourceAssetId,
  }) async {
    final records = await _linkStore.find(
      _db,
      finder: Finder(sortOrders: [SortOrder('updatedAt', false)]),
    );
    return records
        .map((record) =>
            AssetEntityLink.fromJson(Map<String, Object?>.from(record.value)))
        .where((link) =>
            (includeDeleted || !link.isDeleted) &&
            (sourceAssetId == null || link.sourceAssetId == sourceAssetId))
        .toList(growable: false);
  }

  Future<int> pendingOutboxCount() => _outboxStore.count(_db);

  Future<List<Map<String, Object?>>> listOutbox({
    bool includeBlocked = true,
  }) async {
    final records = await _outboxStore.find(
      _db,
      finder: Finder(sortOrders: [SortOrder('clientModifiedAt')]),
    );
    return records
        .map((record) => Map<String, Object?>.from(record.value))
        .where((item) => includeBlocked || item['blocked'] != true)
        .toList(growable: false);
  }

  Future<List<Map<String, Object?>>> listPushableOutboxHeads({
    int limit = 100,
    Set<String>? entityTypes,
  }) async {
    final ordered = await listOutbox(includeBlocked: true);
    final seen = <String>{};
    final heads = <Map<String, Object?>>[];
    for (final item in ordered) {
      final entityType = item['entityType']?.toString() ?? '';
      if (entityTypes != null && !entityTypes.contains(entityType)) continue;
      final key = '$entityType:${item['entityId']}';
      if (!seen.add(key)) continue;
      if (item['blocked'] == true) continue;
      heads.add(item);
      if (heads.length >= limit) break;
    }
    return heads;
  }

  Future<List<AssetSyncIssue>> listSyncIssues() async {
    final items = await listOutbox(includeBlocked: true);
    return items
        .where(
          (item) =>
              item['blocked'] == true &&
              item['errorCode']?.toString() != 'SYNC_CONFLICT',
        )
        .map(
          (item) => AssetSyncIssue(
            changeId: item['id']?.toString() ?? '',
            entityType: item['entityType']?.toString() ?? '',
            entityId: item['entityId']?.toString() ?? '',
            errorCode: item['errorCode']?.toString() ?? 'SYNC_REJECTED',
            message: item['lastError']?.toString() ?? '同步变更已被阻塞',
          ),
        )
        .toList(growable: false);
  }

  Future<List<AssetSyncConflict>> listConflicts() async {
    final records = await _conflictStore.find(
      _db,
      finder: Finder(sortOrders: [SortOrder('createdAt', false)]),
    );
    return records
        .map((record) => AssetSyncConflict.fromJson(
              Map<String, Object?>.from(record.value),
            ))
        .toList(growable: false);
  }

  Future<AssetSyncState> getSyncState() async {
    final raw = await _syncStateStore.record(_syncStateKey).get(_db);
    return raw == null
        ? const AssetSyncState()
        : AssetSyncState.fromJson(Map<String, Object?>.from(raw));
  }

  Future<void> bindCloudUser(String userId) async {
    final state = await getSyncState();
    if (state.boundUserId != null && state.boundUserId != userId) {
      throw StateError(
        '本地资产数据已绑定另一个 LifeTrace Cloud 账号；请先导出或清空本地数据。',
      );
    }
    if (state.boundUserId == userId) return;
    await _syncStateStore
        .record(_syncStateKey)
        .put(_db, state.copyWith(boundUserId: userId).toJson());
  }

  Future<void> saveSnapshotProgress({
    required String snapshotId,
    required String? pageToken,
    required String snapshotCursor,
    required bool completed,
  }) async {
    final state = await getSyncState();
    final next = completed
        ? state.copyWith(
            cursor: snapshotCursor,
            clearSnapshotId: true,
            clearSnapshotPageToken: true,
            clearSnapshotCursor: true,
          )
        : state.copyWith(
            snapshotId: snapshotId,
            snapshotPageToken: pageToken,
            snapshotCursor: snapshotCursor,
          );
    await _syncStateStore.record(_syncStateKey).put(_db, next.toJson());
  }

  Future<void> setSyncCursor(String cursor) async {
    final state = await getSyncState();
    await _syncStateStore.record(_syncStateKey).put(
          _db,
          state.copyWith(
            cursor: cursor,
            clearSnapshotId: true,
            clearSnapshotPageToken: true,
            clearSnapshotCursor: true,
          ).toJson(),
        );
  }

  Future<AssetItem> upsertAsset(AssetItem asset) async {
    final now = DateTime.now();
    final normalized = asset.copyWith(
      updatedAt: now,
      createdAt: asset.createdAt,
      isDeleted: false,
    );
    await _db.transaction((txn) async {
      await _assetStore.record(normalized.id).put(txn, normalized.toJson());
      await _enqueue(
        txn,
        entityType: 'asset.asset',
        entityId: normalized.id,
        operation: 'upsert',
        payload: normalized.toJson(),
        baseServerVersion: normalized.serverVersion,
        modifiedAt: now,
      );
    });
    return normalized;
  }

  Future<void> deleteAsset(String assetId) async {
    final now = DateTime.now();
    await _db.transaction((txn) async {
      final raw = await _assetStore.record(assetId).get(txn);
      if (raw == null) return;
      final asset = AssetItem.fromJson(Map<String, Object?>.from(raw));
      if (asset.isDeleted) return;

      final deleted = asset.copyWith(isDeleted: true, updatedAt: now);
      await _assetStore.record(assetId).put(txn, deleted.toJson());
      await _enqueue(
        txn,
        entityType: 'asset.asset',
        entityId: assetId,
        operation: 'delete',
        payload: null,
        baseServerVersion: asset.serverVersion,
        modifiedAt: now,
      );

      final related = await _eventStore.find(
        txn,
        finder: Finder(filter: Filter.equals('assetId', assetId)),
      );
      for (final record in related) {
        final event =
            AssetEvent.fromJson(Map<String, Object?>.from(record.value));
        if (event.isDeleted) continue;
        final deletedEvent = event.copyWith(isDeleted: true, updatedAt: now);
        await _eventStore.record(event.id).put(txn, deletedEvent.toJson());
        await _enqueue(
          txn,
          entityType: 'asset.event',
          entityId: event.id,
          operation: 'delete',
          payload: null,
          baseServerVersion: event.serverVersion,
          modifiedAt: now,
        );
      }

      final relatedLinks = await _linkStore.find(
        txn,
        finder: Finder(filter: Filter.equals('sourceAssetId', assetId)),
      );
      for (final record in relatedLinks) {
        final link =
            AssetEntityLink.fromJson(Map<String, Object?>.from(record.value));
        if (link.isDeleted) continue;
        final deletedLink = link.copyWith(
          isDeleted: true,
          updatedAt: now,
          localVersion: link.localVersion + 1,
        );
        await _linkStore.record(link.id).put(txn, deletedLink.toJson());
        await _enqueue(
          txn,
          entityType: 'entity.link',
          entityId: link.id,
          operation: 'delete',
          payload: null,
          baseServerVersion: link.serverVersion,
          modifiedAt: now,
        );
      }
    });
  }

  Future<AssetEvent> upsertEvent(AssetEvent event) async {
    final now = DateTime.now();
    final normalized = event.copyWith(
      updatedAt: now,
      createdAt: event.createdAt,
      isDeleted: false,
    );

    await _db.transaction((txn) async {
      final assetRaw = await _assetStore.record(normalized.assetId).get(txn);
      if (assetRaw == null) {
        throw StateError('Cannot add an event to a missing asset.');
      }
      final asset = AssetItem.fromJson(Map<String, Object?>.from(assetRaw));
      if (asset.isDeleted) {
        throw StateError('Cannot add an event to a deleted asset.');
      }

      await _eventStore.record(normalized.id).put(txn, normalized.toJson());
      await _enqueue(
        txn,
        entityType: 'asset.event',
        entityId: normalized.id,
        operation: 'upsert',
        payload: normalized.toJson(),
        baseServerVersion: normalized.serverVersion,
        modifiedAt: now,
      );
      await _recalculateAsset(txn, normalized.assetId, now);
    });

    return normalized;
  }

  Future<void> deleteEvent(String eventId) async {
    final now = DateTime.now();
    await _db.transaction((txn) async {
      final raw = await _eventStore.record(eventId).get(txn);
      if (raw == null) return;
      final event = AssetEvent.fromJson(Map<String, Object?>.from(raw));
      if (event.isDeleted) return;

      final deleted = event.copyWith(isDeleted: true, updatedAt: now);
      await _eventStore.record(eventId).put(txn, deleted.toJson());
      await _enqueue(
        txn,
        entityType: 'asset.event',
        entityId: eventId,
        operation: 'delete',
        payload: null,
        baseServerVersion: event.serverVersion,
        modifiedAt: now,
      );
      await _recalculateAsset(txn, event.assetId, now);
    });
  }

  Future<AssetEntityLink> upsertLink(AssetEntityLink link) async {
    final now = DateTime.now();
    if (link.userId.trim().isEmpty) {
      throw const FormatException('EntityLink requires a bound user ID');
    }
    if (link.targetEntityType.trim().isEmpty ||
        link.targetEntityId.trim().isEmpty ||
        link.relationType.trim().isEmpty) {
      throw const FormatException('EntityLink target and relation are required');
    }
    if (link.targetEntityType == 'asset.asset' &&
        link.targetEntityId == link.sourceAssetId) {
      throw const FormatException('EntityLink cannot target the same asset');
    }

    late AssetEntityLink normalized;
    await _db.transaction((txn) async {
      final assetRaw = await _assetStore.record(link.sourceAssetId).get(txn);
      if (assetRaw == null) {
        throw StateError('Cannot link from a missing asset.');
      }
      final asset = AssetItem.fromJson(Map<String, Object?>.from(assetRaw));
      if (asset.isDeleted) {
        throw StateError('Cannot link from a deleted asset.');
      }

      final existingRaw = await _linkStore.record(link.id).get(txn);
      final existing = existingRaw == null
          ? null
          : AssetEntityLink.fromJson(
              Map<String, Object?>.from(existingRaw),
            );
      normalized = link.copyWith(
        createdAt: existing?.createdAt ?? link.createdAt,
        updatedAt: now,
        localVersion: existing == null
            ? (link.localVersion < 1 ? 1 : link.localVersion)
            : existing.localVersion + 1,
        isDeleted: false,
        serverVersion: existing?.serverVersion ?? link.serverVersion,
      );

      await _linkStore.record(normalized.id).put(txn, normalized.toJson());
      await _enqueue(
        txn,
        entityType: 'entity.link',
        entityId: normalized.id,
        operation: 'upsert',
        payload: normalized.toCloudJson(),
        baseServerVersion: normalized.serverVersion,
        modifiedAt: now,
      );
    });
    return normalized;
  }

  Future<void> deleteLink(String linkId) async {
    final now = DateTime.now();
    await _db.transaction((txn) async {
      final raw = await _linkStore.record(linkId).get(txn);
      if (raw == null) return;
      final link = AssetEntityLink.fromJson(Map<String, Object?>.from(raw));
      if (link.isDeleted) return;

      final deleted = link.copyWith(
        isDeleted: true,
        updatedAt: now,
        localVersion: link.localVersion + 1,
      );
      await _linkStore.record(linkId).put(txn, deleted.toJson());
      await _enqueue(
        txn,
        entityType: 'entity.link',
        entityId: linkId,
        operation: 'delete',
        payload: null,
        baseServerVersion: link.serverVersion,
        modifiedAt: now,
      );
    });
  }

  Future<void> markOutboxAttempt(String changeId) async {
    await _db.transaction((txn) async {
      final raw = await _outboxStore.record(changeId).get(txn);
      if (raw == null) return;
      final next = Map<String, Object?>.from(raw);
      next['attempts'] = ((next['attempts'] as num?)?.toInt() ?? 0) + 1;
      next['lastError'] = null;
      await _outboxStore.record(changeId).put(txn, next);
    });
  }

  Future<void> markOutboxRejected(
    String changeId, {
    required String code,
    required String message,
  }) async {
    await _db.transaction((txn) async {
      final raw = await _outboxStore.record(changeId).get(txn);
      if (raw == null) return;
      final next = Map<String, Object?>.from(raw)
        ..['blocked'] = true
        ..['errorCode'] = code
        ..['lastError'] = message;
      await _outboxStore.record(changeId).put(txn, next);
    });
  }

  Future<void> markOutboxTransportError(
    Iterable<String> changeIds,
    String message,
  ) async {
    await _db.transaction((txn) async {
      for (final changeId in changeIds) {
        final raw = await _outboxStore.record(changeId).get(txn);
        if (raw == null) continue;
        final next = Map<String, Object?>.from(raw)..['lastError'] = message;
        await _outboxStore.record(changeId).put(txn, next);
      }
    });
  }

  Future<void> acknowledgeChange({
    required String changeId,
    required String entityType,
    required String entityId,
    required String serverVersion,
  }) async {
    await _db.transaction((txn) async {
      await _setEntityServerVersion(
        txn,
        entityType,
        entityId,
        serverVersion,
      );
      await _outboxStore.record(changeId).delete(txn);

      final remaining = await _outboxForEntity(
        txn,
        entityType,
        entityId,
        includeBlocked: true,
      );
      if (remaining.isEmpty) return;
      final first = remaining.first;
      final next = Map<String, Object?>.from(first.value)
        ..['baseServerVersion'] = serverVersion;
      final payload = next['payload'];
      if (payload is Map) {
        next['payload'] = _payloadWithServerVersion(
          entityType,
          Map<String, Object?>.from(payload),
          serverVersion,
        );
      }
      await _outboxStore.record(first.key).put(txn, next);
    });
  }

  Future<void> persistConflict(AssetSyncConflict conflict) async {
    await _db.transaction((txn) async {
      await _conflictStore.record(conflict.id).put(txn, conflict.toJson());
      final records = await _outboxForEntity(
        txn,
        conflict.entityType,
        conflict.entityId,
        includeBlocked: true,
      );
      for (final record in records) {
        final next = Map<String, Object?>.from(record.value)
          ..['blocked'] = true
          ..['errorCode'] = 'SYNC_CONFLICT'
          ..['lastError'] = conflict.reason;
        await _outboxStore.record(record.key).put(txn, next);
      }
    });
  }

  Future<void> resolveConflictUseServer(String conflictId) async {
    await _db.transaction((txn) async {
      final raw = await _conflictStore.record(conflictId).get(txn);
      if (raw == null) return;
      final conflict =
          AssetSyncConflict.fromJson(Map<String, Object?>.from(raw));
      final pending = await _outboxForEntity(
        txn,
        conflict.entityType,
        conflict.entityId,
        includeBlocked: true,
      );
      for (final record in pending) {
        await _outboxStore.record(record.key).delete(txn);
      }
      await _applyRemoteInTxn(
        txn,
        entityType: conflict.entityType,
        entityId: conflict.entityId,
        operation: conflict.serverDeleted ? 'delete' : 'upsert',
        serverVersion: conflict.currentServerVersion,
        payload: conflict.serverPayload,
      );
      await _conflictStore.record(conflictId).delete(txn);
    });
  }

  Future<void> resolveConflictKeepLocal(String conflictId) async {
    await _db.transaction((txn) async {
      final raw = await _conflictStore.record(conflictId).get(txn);
      if (raw == null) return;
      final conflict =
          AssetSyncConflict.fromJson(Map<String, Object?>.from(raw));
      final pending = await _outboxForEntity(
        txn,
        conflict.entityType,
        conflict.entityId,
        includeBlocked: true,
      );
      for (var i = 0; i < pending.length; i++) {
        final record = pending[i];
        final next = Map<String, Object?>.from(record.value)
          ..['blocked'] = false
          ..['errorCode'] = null
          ..['lastError'] = null;
        if (i == 0) {
          next['baseServerVersion'] = conflict.currentServerVersion;
          final payload = next['payload'];
          if (payload is Map) {
            next['payload'] = _payloadWithServerVersion(
              conflict.entityType,
              Map<String, Object?>.from(payload),
              conflict.currentServerVersion,
            );
          }
        }
        await _outboxStore.record(record.key).put(txn, next);
      }
      await _conflictStore.record(conflictId).delete(txn);
    });
  }

  Future<bool> hasPendingForEntity(
    String entityType,
    String entityId,
  ) async {
    final count = await _outboxStore.count(
      _db,
      filter: Filter.and([
        Filter.equals('entityType', entityType),
        Filter.equals('entityId', entityId),
      ]),
    );
    return count > 0;
  }

  Future<void> applyRemoteChange({
    required String entityType,
    required String entityId,
    required String operation,
    required String serverVersion,
    Map<String, Object?>? payload,
  }) async {
    await _db.transaction((txn) async {
      final pending = await _outboxForEntity(
        txn,
        entityType,
        entityId,
        includeBlocked: true,
      );
      if (pending.isNotEmpty) return;
      await _applyRemoteInTxn(
        txn,
        entityType: entityType,
        entityId: entityId,
        operation: operation,
        serverVersion: serverVersion,
        payload: payload,
      );
    });
  }

  Future<void> _applyRemoteInTxn(
    Transaction txn, {
    required String entityType,
    required String entityId,
    required String operation,
    required String serverVersion,
    Map<String, Object?>? payload,
  }) async {
    if (operation == 'delete') {
      if (entityType == 'asset.asset') {
        await _assetStore.record(entityId).delete(txn);
      } else if (entityType == 'asset.event') {
        await _eventStore.record(entityId).delete(txn);
      } else if (entityType == 'entity.link') {
        await _linkStore.record(entityId).delete(txn);
      }
      return;
    }
    if (operation != 'upsert' || payload == null) {
      throw FormatException('Unsupported remote asset operation: $operation');
    }
    if (entityType == 'asset.asset') {
      final asset = AssetItem.fromJson(payload).copyWith(
        serverVersion: serverVersion,
        isDeleted: false,
      );
      if (asset.id != entityId) {
        throw const FormatException('asset.asset payload id mismatch');
      }
      await _assetStore.record(entityId).put(txn, asset.toJson());
    } else if (entityType == 'asset.event') {
      final event = AssetEvent.fromJson(payload).copyWith(
        serverVersion: serverVersion,
        isDeleted: false,
      );
      if (event.id != entityId) {
        throw const FormatException('asset.event payload id mismatch');
      }
      await _eventStore.record(entityId).put(txn, event.toJson());
    } else if (entityType == 'entity.link') {
      final link = AssetEntityLink.tryFromCloudJson(
        payload,
        serverVersion: serverVersion,
      );
      if (link == null) return;
      if (link.id != entityId) {
        throw const FormatException('entity.link payload id mismatch');
      }
      await _linkStore.record(entityId).put(txn, link.toJson());
    }
  }

  Future<void> _setEntityServerVersion(
    Transaction txn,
    String entityType,
    String entityId,
    String serverVersion,
  ) async {
    final store = switch (entityType) {
      'asset.asset' => _assetStore,
      'asset.event' => _eventStore,
      'entity.link' => _linkStore,
      _ => null,
    };
    if (store == null) return;
    final raw = await store.record(entityId).get(txn);
    if (raw == null) return;
    final next = Map<String, Object?>.from(raw)
      ..['serverVersion'] = serverVersion;
    await store.record(entityId).put(txn, next);
  }

  Map<String, Object?> _payloadWithServerVersion(
    String entityType,
    Map<String, Object?> payload,
    String serverVersion,
  ) {
    if (entityType != 'entity.link') {
      return payload..['serverVersion'] = serverVersion;
    }
    final rawMeta = payload['meta'];
    if (rawMeta is! Map) {
      throw const FormatException('entity.link payload is missing meta');
    }
    final meta = Map<String, Object?>.from(rawMeta)
      ..['serverVersion'] = serverVersion;
    return payload..['meta'] = meta;
  }

  Future<List<RecordSnapshot<String, Map<String, Object?>>>>
      _outboxForEntity(
    Transaction txn,
    String entityType,
    String entityId, {
    required bool includeBlocked,
  }) async {
    final records = await _outboxStore.find(
      txn,
      finder: Finder(
        filter: Filter.and([
          Filter.equals('entityType', entityType),
          Filter.equals('entityId', entityId),
        ]),
        sortOrders: [SortOrder('clientModifiedAt')],
      ),
    );
    return includeBlocked
        ? records
        : records.where((record) => record.value['blocked'] != true).toList();
  }

  Future<void> _recalculateAsset(
    Transaction txn,
    String assetId,
    DateTime now,
  ) async {
    final assetRaw = await _assetStore.record(assetId).get(txn);
    if (assetRaw == null) return;
    final asset = AssetItem.fromJson(Map<String, Object?>.from(assetRaw));
    if (asset.isDeleted) return;

    final records = await _eventStore.find(
      txn,
      finder: Finder(
        filter: Filter.equals('assetId', assetId),
        sortOrders: [SortOrder('date')],
      ),
    );
    final events = records
        .map((record) =>
            AssetEvent.fromJson(Map<String, Object?>.from(record.value)))
        .where((event) => !event.isDeleted)
        .toList(growable: false);

    var maintenanceCost = 0.0;
    var recoveredAmount = 0.0;
    var currentValue = asset.currentValue;
    var status = asset.status;

    for (final event in events) {
      final amount = event.amount ?? 0;
      switch (event.type) {
        case AssetEventType.maintenance:
        case AssetEventType.repair:
        case AssetEventType.replacement:
          if (amount > 0) maintenanceCost += amount;
          if (event.type == AssetEventType.repair) {
            status = AssetStatus.repair;
          }
          break;
        case AssetEventType.sell:
          if (amount > 0) recoveredAmount += amount;
          status = AssetStatus.sold;
          break;
        case AssetEventType.valuation:
          if (event.amount != null && event.amount! >= 0) {
            currentValue = event.amount!;
          }
          break;
        case AssetEventType.idle:
          status = AssetStatus.idle;
          break;
        case AssetEventType.lend:
          status = AssetStatus.lent;
          break;
        case AssetEventType.returnItem:
        case AssetEventType.useStart:
          status = AssetStatus.active;
          break;
        case AssetEventType.retire:
          status = AssetStatus.retired;
          break;
        case AssetEventType.purchase:
        case AssetEventType.note:
          break;
      }
    }

    final updated = asset.copyWith(
      maintenanceCost: maintenanceCost,
      recoveredAmount: recoveredAmount,
      currentValue: currentValue,
      status: status,
      updatedAt: now,
    );
    await _assetStore.record(assetId).put(txn, updated.toJson());
    await _enqueue(
      txn,
      entityType: 'asset.asset',
      entityId: assetId,
      operation: 'upsert',
      payload: updated.toJson(),
      baseServerVersion: updated.serverVersion,
      modifiedAt: now,
    );
  }

  Future<void> _enqueue(
    Transaction txn, {
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, Object?>? payload,
    required String baseServerVersion,
    required DateTime modifiedAt,
  }) async {
    final item = SyncOutboxItem(
      id: newEntityId('change'),
      entityType: entityType,
      entityId: entityId,
      operation: operation,
      payload: payload,
      baseServerVersion: baseServerVersion,
      clientModifiedAt: modifiedAt,
    );
    final json = item.toJson()..['blocked'] = false;
    await _outboxStore.record(item.id).put(txn, json);
  }

  Future<String> exportBackupJson() async {
    final assets = await listAssets(includeDeleted: false);
    final validIds = assets.map((asset) => asset.id).toSet();
    final events = (await listEvents(includeDeleted: false))
        .where((event) => validIds.contains(event.assetId))
        .toList(growable: false);
    final links = (await listLinks(includeDeleted: false))
        .where((link) => validIds.contains(link.sourceAssetId))
        .toList(growable: false);
    return const JsonEncoder.withIndent('  ').convert({
      'format': 'lifetrace-assets-backup',
      'version': 2,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'assets': assets.map((asset) => asset.toJson()).toList(growable: false),
      'events': events.map((event) => event.toJson()).toList(growable: false),
      'links': links.map((link) => link.toJson()).toList(growable: false),
    });
  }

  Future<void> importBackupJson(String raw) async {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('备份必须是 JSON 对象');
    }
    final root = Map<String, Object?>.from(decoded);
    final version = (root['version'] as num?)?.toInt();
    if (root['format'] != 'lifetrace-assets-backup' ||
        (version != 1 && version != 2)) {
      throw const FormatException('不支持的 LifeTrace Assets 备份格式或版本');
    }

    final rawAssets = root['assets'];
    final rawEvents = root['events'];
    final rawLinks = version == 2 ? root['links'] : const <Object?>[];
    if (rawAssets is! List || rawEvents is! List || rawLinks is! List) {
      throw const FormatException('备份缺少 assets、events 或 links');
    }

    final assets = rawAssets.map((value) {
      if (value is! Map) throw const FormatException('asset 不是对象');
      return AssetItem.fromJson(Map<String, Object?>.from(value));
    }).where((asset) => asset.id.isNotEmpty && !asset.isDeleted).toList();

    final assetIds = assets.map((asset) => asset.id).toSet();
    final events = rawEvents.map((value) {
      if (value is! Map) throw const FormatException('event 不是对象');
      return AssetEvent.fromJson(Map<String, Object?>.from(value));
    }).where((event) =>
        event.id.isNotEmpty &&
        assetIds.contains(event.assetId) &&
        !event.isDeleted).toList();

    final links = rawLinks.map((value) {
      if (value is! Map) throw const FormatException('link 不是对象');
      return AssetEntityLink.fromJson(Map<String, Object?>.from(value));
    }).where((link) =>
        link.id.isNotEmpty &&
        link.userId.isNotEmpty &&
        assetIds.contains(link.sourceAssetId) &&
        link.targetEntityType.isNotEmpty &&
        link.targetEntityId.isNotEmpty &&
        link.relationType.isNotEmpty &&
        !link.isDeleted).toList();

    final now = DateTime.now();
    await _db.transaction((txn) async {
      await _assetStore.delete(txn);
      await _eventStore.delete(txn);
      await _linkStore.delete(txn);
      await _outboxStore.delete(txn);
      await _conflictStore.delete(txn);
      await _syncStateStore.delete(txn);

      for (final asset in assets) {
        final imported = asset.copyWith(updatedAt: now, isDeleted: false, serverVersion: '0');
        await _assetStore.record(imported.id).put(txn, imported.toJson());
        await _enqueue(
          txn,
          entityType: 'asset.asset',
          entityId: imported.id,
          operation: 'upsert',
          payload: imported.toJson(),
          baseServerVersion: imported.serverVersion,
          modifiedAt: now,
        );
      }
      for (final event in events) {
        final imported = event.copyWith(updatedAt: now, isDeleted: false, serverVersion: '0');
        await _eventStore.record(imported.id).put(txn, imported.toJson());
        await _enqueue(
          txn,
          entityType: 'asset.event',
          entityId: imported.id,
          operation: 'upsert',
          payload: imported.toJson(),
          baseServerVersion: imported.serverVersion,
          modifiedAt: now,
        );
      }
      for (final link in links) {
        final imported = link.copyWith(
          updatedAt: now,
          isDeleted: false,
          serverVersion: '0',
        );
        await _linkStore.record(imported.id).put(txn, imported.toJson());
        await _enqueue(
          txn,
          entityType: 'entity.link',
          entityId: imported.id,
          operation: 'upsert',
          payload: imported.toCloudJson(),
          baseServerVersion: imported.serverVersion,
          modifiedAt: now,
        );
      }
    });
  }

  Future<void> clearAll() async {
    await _db.transaction((txn) async {
      await _assetStore.delete(txn);
      await _eventStore.delete(txn);
      await _linkStore.delete(txn);
      await _outboxStore.delete(txn);
      await _conflictStore.delete(txn);
      await _syncStateStore.delete(txn);
    });
  }

  Future<void> close() => _db.close();
}
