import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../local/app_database.dart' as db;
import '../repository/habit_repository.dart';

class HabitConflictResolver {
  HabitConflictResolver(this.database, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  final db.AppDatabase database;
  final Uuid _uuid;

  Future<void> keepServer(String conflictId) async {
    await database.transaction(() async {
      final conflict = await _load(conflictId);
      if (conflict == null) return;
      _requireHabitType(conflict.entityType);

      await _deleteOutbox(
        conflict.userId,
        conflict.entityType,
        conflict.entityId,
      );

      if (conflict.serverDeleted) {
        await _deleteLocal(
          conflict.userId,
          conflict.entityType,
          conflict.entityId,
        );
      } else {
        final payload = conflict.serverPayloadJson;
        final version = conflict.serverVersion;
        if (payload == null || version == null || version.isEmpty) {
          throw StateError('云端习惯冲突缺少内容或版本');
        }
        final decoded = _decodeObject(payload);
        switch (conflict.entityType) {
          case DriftHabitRepository.activityEntityType:
            final activity = HabitActivityWireMapper.fromPayload(
              decoded,
              serverVersion: version,
            );
            await database
                .into(database.habitActivities)
                .insertOnConflictUpdate(
                  HabitActivityDatabaseMapper.toRow(activity),
                );
          case DriftHabitRepository.logEntityType:
            final log = HabitLogWireMapper.fromPayload(
              decoded,
              serverVersion: version,
            );
            await database
                .into(database.habitLogs)
                .insertOnConflictUpdate(HabitLogDatabaseMapper.toRow(log));
        }
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
      _requireHabitType(conflict.entityType);

      final version = conflict.serverVersion;
      if (version == null || version.isEmpty) {
        throw StateError('习惯冲突缺少最新云端版本');
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
      if (queued == null) {
        throw StateError('习惯冲突缺少本地待同步变更');
      }

      final now = DateTime.now().toUtc().toIso8601String();
      await _deleteOutbox(
        conflict.userId,
        conflict.entityType,
        conflict.entityId,
      );

      switch (queued.operation) {
        case 'delete':
          await _deleteLocal(
            conflict.userId,
            conflict.entityType,
            conflict.entityId,
          );
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
        case 'upsert':
          final payload = await _rebaseLocal(
            userId: conflict.userId,
            entityType: conflict.entityType,
            entityId: conflict.entityId,
            serverVersion: version,
            deviceId: deviceId,
            updatedAt: now,
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
                  payloadJson: Value(jsonEncode(payload)),
                  createdAt: now,
                ),
              );
        default:
          throw StateError('不支持的习惯冲突变更类型：${queued.operation}');
      }

      await _deleteConflicts(
        conflict.userId,
        conflict.entityType,
        conflict.entityId,
      );
    });
  }

  Future<Map<String, dynamic>> _rebaseLocal({
    required String userId,
    required String entityType,
    required String entityId,
    required String serverVersion,
    required String deviceId,
    required String updatedAt,
  }) async {
    switch (entityType) {
      case DriftHabitRepository.activityEntityType:
        final row = await (database.select(database.habitActivities)
              ..where(
                (table) =>
                    table.userId.equals(userId) & table.id.equals(entityId),
              ))
            .getSingleOrNull();
        if (row == null) throw StateError('本地 HabitActivity 已不存在');
        final local = HabitActivityDatabaseMapper.fromRow(row).copyWith(
          updatedAt: updatedAt,
          localVersion: row.localVersion + 1,
          serverVersion: serverVersion,
          modifiedByDevice: deviceId,
        );
        await database
            .into(database.habitActivities)
            .insertOnConflictUpdate(HabitActivityDatabaseMapper.toRow(local));
        return HabitActivityWireMapper.toPayload(local);
      case DriftHabitRepository.logEntityType:
        final row = await (database.select(database.habitLogs)
              ..where(
                (table) =>
                    table.userId.equals(userId) & table.id.equals(entityId),
              ))
            .getSingleOrNull();
        if (row == null) throw StateError('本地 HabitLog 已不存在');
        final local = HabitLogDatabaseMapper.fromRow(row).copyWith(
          updatedAt: updatedAt,
          localVersion: row.localVersion + 1,
          serverVersion: serverVersion,
          modifiedByDevice: deviceId,
        );
        await database
            .into(database.habitLogs)
            .insertOnConflictUpdate(HabitLogDatabaseMapper.toRow(local));
        return HabitLogWireMapper.toPayload(local);
      default:
        throw StateError('仅支持处理习惯冲突');
    }
  }

  Future<db.SyncConflict?> _load(String conflictId) =>
      (database.select(database.syncConflicts)
            ..where((table) => table.id.equals(conflictId)))
          .getSingleOrNull();

  Future<void> _deleteLocal(
    String userId,
    String entityType,
    String entityId,
  ) async {
    switch (entityType) {
      case DriftHabitRepository.activityEntityType:
        await (database.delete(database.habitActivities)
              ..where(
                (table) =>
                    table.userId.equals(userId) & table.id.equals(entityId),
              ))
            .go();
      case DriftHabitRepository.logEntityType:
        await (database.delete(database.habitLogs)
              ..where(
                (table) =>
                    table.userId.equals(userId) & table.id.equals(entityId),
              ))
            .go();
      default:
        throw StateError('仅支持处理习惯冲突');
    }
  }

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

  static void _requireHabitType(String entityType) {
    if (entityType != DriftHabitRepository.activityEntityType &&
        entityType != DriftHabitRepository.logEntityType) {
      throw StateError('仅支持处理习惯冲突');
    }
  }

  static Map<String, dynamic> _decodeObject(String raw) {
    final value = jsonDecode(raw);
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException('Habit conflict payload must be object');
  }
}
