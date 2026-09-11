import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/collection/entity_link.dart';
import '../local/app_database.dart' as db;
import '../repository/entity_link_repository.dart';
import '../repository/memo_repository.dart';

class CollectionConflictResolver {
  CollectionConflictResolver(this.database, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  final db.AppDatabase database;
  final Uuid _uuid;

  Future<void> keepServer(String conflictId) async {
    await database.transaction(() async {
      final conflict = await _load(conflictId);
      if (conflict == null) return;

      await _deleteOutbox(
        conflict.userId,
        conflict.entityType,
        conflict.entityId,
      );

      switch (conflict.entityType) {
        case DriftMemoRepository.entityType:
          if (conflict.serverDeleted) {
            await (database.delete(database.memos)
                  ..where(
                    (table) =>
                        table.userId.equals(conflict.userId) &
                        table.id.equals(conflict.entityId),
                  ))
                .go();
          } else {
            final payload = conflict.serverPayloadJson;
            final version = conflict.serverVersion;
            if (payload == null || version == null) {
              throw StateError('云端 Memo 冲突缺少内容');
            }
            final memo = MemoWireMapper.fromPayload(
              _decodeObject(payload),
              serverVersion: version,
            );
            await database
                .into(database.memos)
                .insertOnConflictUpdate(MemoDatabaseMapper.toRow(memo));
          }
        case DriftEntityLinkRepository.entityType:
          if (conflict.serverDeleted) {
            await (database.delete(database.entityLinks)
                  ..where(
                    (table) =>
                        table.userId.equals(conflict.userId) &
                        table.id.equals(conflict.entityId),
                  ))
                .go();
          } else {
            final payload = conflict.serverPayloadJson;
            final version = conflict.serverVersion;
            if (payload == null || version == null) {
              throw StateError('云端 EntityLink 冲突缺少内容');
            }
            final link = EntityLinkWireMapper.fromPayload(
              _decodeObject(payload),
              serverVersion: version,
            );
            await database
                .into(database.entityLinks)
                .insertOnConflictUpdate(EntityLinkDatabaseMapper.toRow(link));
          }
        default:
          throw StateError('不支持的 Collection 冲突类型');
      }

      await _deleteConflicts(
        conflict.userId,
        conflict.entityType,
        conflict.entityId,
      );
    });
  }

  Future<void> keepLocal({
    required String conflictId,
    required String deviceId,
  }) async {
    await database.transaction(() async {
      final conflict = await _load(conflictId);
      if (conflict == null) return;
      final version = conflict.serverVersion;
      if (version == null || version.isEmpty) {
        throw StateError('冲突缺少最新云端版本');
      }

      final queued = await (database.select(database.syncOutbox)
            ..where(
              (table) =>
                  table.userId.equals(conflict.userId) &
                  table.entityType.equals(conflict.entityType) &
                  table.entityId.equals(conflict.entityId),
            )
            ..orderBy([
              (table) => OrderingTerm.asc(table.createdAt),
              (table) => OrderingTerm.asc(table.changeId),
            ])
            ..limit(1))
          .getSingleOrNull();
      if (queued == null) throw StateError('冲突缺少本地待同步变更');

      final now = DateTime.now().toUtc().toIso8601String();
      await _deleteOutbox(
        conflict.userId,
        conflict.entityType,
        conflict.entityId,
      );

      switch (conflict.entityType) {
        case DriftMemoRepository.entityType:
          if (queued.operation == 'delete') {
            await database.into(database.syncOutbox).insert(
                  db.SyncOutboxCompanion.insert(
                    changeId: _uuid.v4(),
                    userId: conflict.userId,
                    entityType: conflict.entityType,
                    entityId: conflict.entityId,
                    operation: 'delete',
                    baseServerVersion: version,
                    clientModifiedAt: now,
                    createdAt: now,
                  ),
                );
          } else {
            final row = await (database.select(database.memos)
                  ..where(
                    (table) =>
                        table.userId.equals(conflict.userId) &
                        table.id.equals(conflict.entityId),
                  ))
                .getSingleOrNull();
            if (row == null) throw StateError('本地 Memo 已不存在');
            final local = MemoDatabaseMapper.fromRow(row).copyWith(
              updatedAt: now,
              localVersion: row.localVersion + 1,
              serverVersion: version,
              modifiedByDevice: deviceId,
            );
            await database
                .into(database.memos)
                .insertOnConflictUpdate(MemoDatabaseMapper.toRow(local));
            await database.into(database.syncOutbox).insert(
                  db.SyncOutboxCompanion.insert(
                    changeId: _uuid.v4(),
                    userId: conflict.userId,
                    entityType: conflict.entityType,
                    entityId: conflict.entityId,
                    operation: 'upsert',
                    baseServerVersion: version,
                    clientModifiedAt: now,
                    payloadJson: Value(
                      jsonEncode(MemoWireMapper.toPayload(local)),
                    ),
                    createdAt: now,
                  ),
                );
          }
        case DriftEntityLinkRepository.entityType:
          if (queued.operation == 'delete') {
            await database.into(database.syncOutbox).insert(
                  db.SyncOutboxCompanion.insert(
                    changeId: _uuid.v4(),
                    userId: conflict.userId,
                    entityType: conflict.entityType,
                    entityId: conflict.entityId,
                    operation: 'delete',
                    baseServerVersion: version,
                    clientModifiedAt: now,
                    createdAt: now,
                  ),
                );
          } else {
            final row = await (database.select(database.entityLinks)
                  ..where(
                    (table) =>
                        table.userId.equals(conflict.userId) &
                        table.id.equals(conflict.entityId),
                  ))
                .getSingleOrNull();
            if (row == null) throw StateError('本地 EntityLink 已不存在');
            final local = EntityLinkDatabaseMapper.fromRow(row);
            final rebased = ExecutionEntityLink(
              id: local.id,
              userId: local.userId,
              sourceType: local.sourceType,
              sourceId: local.sourceId,
              targetType: local.targetType,
              targetId: local.targetId,
              relationType: local.relationType,
              metadata: local.metadata,
              createdAt: local.createdAt,
              updatedAt: now,
              localVersion: local.localVersion + 1,
              serverVersion: version,
              modifiedByDevice: deviceId,
            );
            await database
                .into(database.entityLinks)
                .insertOnConflictUpdate(EntityLinkDatabaseMapper.toRow(rebased));
            await database.into(database.syncOutbox).insert(
                  db.SyncOutboxCompanion.insert(
                    changeId: _uuid.v4(),
                    userId: conflict.userId,
                    entityType: conflict.entityType,
                    entityId: conflict.entityId,
                    operation: 'upsert',
                    baseServerVersion: version,
                    clientModifiedAt: now,
                    payloadJson: Value(
                      jsonEncode(EntityLinkWireMapper.toPayload(rebased)),
                    ),
                    dependenciesJson: Value(
                      jsonEncode([
                        {
                          'entityType': rebased.sourceType,
                          'entityId': rebased.sourceId,
                        },
                        {
                          'entityType': rebased.targetType,
                          'entityId': rebased.targetId,
                        },
                      ]),
                    ),
                    createdAt: now,
                  ),
                );
          }
        default:
          throw StateError('不支持的 Collection 冲突类型');
      }

      await _deleteConflicts(
        conflict.userId,
        conflict.entityType,
        conflict.entityId,
      );
    });
  }

  Future<db.SyncConflict?> _load(String conflictId) =>
      (database.select(database.syncConflicts)
            ..where((table) => table.id.equals(conflictId)))
          .getSingleOrNull();

  Future<void> _deleteOutbox(
    String userId,
    String entityType,
    String entityId,
  ) =>
      (database.delete(database.syncOutbox)
            ..where(
              (table) =>
                  table.userId.equals(userId) &
                  table.entityType.equals(entityType) &
                  table.entityId.equals(entityId),
            ))
          .go();

  Future<void> _deleteConflicts(
    String userId,
    String entityType,
    String entityId,
  ) =>
      (database.delete(database.syncConflicts)
            ..where(
              (table) =>
                  table.userId.equals(userId) &
                  table.entityType.equals(entityType) &
                  table.entityId.equals(entityId),
            ))
          .go();

  static Map<String, dynamic> _decodeObject(String raw) {
    final value = jsonDecode(raw);
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException('Collection conflict payload must be object');
  }
}
