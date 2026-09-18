import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../local/app_database.dart' as db;
import '../repository/important_date_repository.dart';

class ImportantDateConflictResolver {
  ImportantDateConflictResolver(this.database, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  final db.AppDatabase database;
  final Uuid _uuid;

  Future<void> keepServer(String conflictId) async {
    await database.transaction(() async {
      final conflict = await _load(conflictId);
      if (conflict == null) return;
      if (conflict.entityType != DriftImportantDateRepository.entityType) {
        throw StateError('仅支持处理重要日期冲突');
      }

      await _deleteOutbox(
        conflict.userId,
        conflict.entityType,
        conflict.entityId,
      );

      if (conflict.serverDeleted) {
        await _deleteImportantDate(conflict.userId, conflict.entityId);
      } else {
        final payload = conflict.serverPayloadJson;
        final version = conflict.serverVersion;
        if (payload == null || version == null) {
          throw StateError('云端 ImportantDate 冲突缺少内容');
        }
        final now = DateTime.now().toUtc().toIso8601String();
        final item = ImportantDateWireMapper.fromPayload(
          _decodeObject(payload),
          serverVersion: version,
          serverModifiedAt: now,
        );
        await database.into(database.importantDates).insertOnConflictUpdate(
              ImportantDateDatabaseMapper.toRow(item),
            );
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
      if (conflict.entityType != DriftImportantDateRepository.entityType) {
        throw StateError('仅支持处理重要日期冲突');
      }
      final version = conflict.serverVersion;
      if (version == null || version.isEmpty) {
        throw StateError('重要日期冲突缺少最新云端版本');
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
      if (queued == null) throw StateError('重要日期冲突缺少本地待同步变更');

      final now = DateTime.now().toUtc().toIso8601String();
      await _deleteOutbox(
        conflict.userId,
        conflict.entityType,
        conflict.entityId,
      );

      if (queued.operation == 'delete') {
        await _deleteImportantDate(conflict.userId, conflict.entityId);
        await database.into(database.syncOutbox).insert(
              db.SyncOutboxCompanion.insert(
                changeId: _uuid.v4(),
                userId: conflict.userId,
                entityType: conflict.entityType,
                entityId: conflict.entityId,
                operation: 'delete',
                baseServerVersion: version,
                entitySchemaVersion: Value(queued.entitySchemaVersion),
                clientModifiedAt: now,
                createdAt: now,
              ),
            );
      } else {
        final row = await (database.select(database.importantDates)
              ..where(
                (table) =>
                    table.userId.equals(conflict.userId) &
                    table.id.equals(conflict.entityId),
              ))
            .getSingleOrNull();
        if (row == null) throw StateError('本地 ImportantDate 已不存在');

        final current = ImportantDateDatabaseMapper.fromRow(row);
        final local = current.copyWith(
          updatedAt: now,
          localVersion: current.localVersion + 1,
          serverVersion: version,
          modifiedByDevice: deviceId,
        );
        await database.into(database.importantDates).insertOnConflictUpdate(
              ImportantDateDatabaseMapper.toRow(local),
            );
        await database.into(database.syncOutbox).insert(
              db.SyncOutboxCompanion.insert(
                changeId: _uuid.v4(),
                userId: conflict.userId,
                entityType: conflict.entityType,
                entityId: conflict.entityId,
                operation: 'upsert',
                baseServerVersion: version,
                entitySchemaVersion: Value(queued.entitySchemaVersion),
                clientModifiedAt: now,
                payloadJson: Value(
                  jsonEncode(ImportantDateWireMapper.toPayload(local)),
                ),
                createdAt: now,
              ),
            );
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

  Future<void> _deleteImportantDate(String userId, String id) =>
      (database.delete(database.importantDates)
            ..where(
              (table) =>
                  table.userId.equals(userId) & table.id.equals(id),
            ))
          .go();

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
    throw const FormatException('ImportantDate conflict payload must be object');
  }
}
