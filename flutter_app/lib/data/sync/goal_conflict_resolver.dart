import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../local/app_database.dart' as db;
import '../repository/goal_repository.dart';

class GoalConflictResolver {
  GoalConflictResolver(this.database, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final db.AppDatabase database;
  final Uuid _uuid;

  Future<void> keepServer(String conflictId) async {
    await database.transaction(() async {
      final conflict = await _load(conflictId);
      if (conflict == null) return;
      _requireGoal(conflict.entityType);

      await _deleteOutbox(conflict.userId, conflict.entityId);
      if (conflict.serverDeleted) {
        await _deleteGoal(conflict.userId, conflict.entityId);
      } else {
        final raw = conflict.serverPayloadJson;
        final version = conflict.serverVersion;
        if (raw == null || version == null || version.isEmpty) {
          throw StateError('服务器冲突结果缺少目标内容');
        }
        final goal = GoalWireMapper.fromPayload(
          _decodeObject(raw),
          serverVersion: version,
        );
        await database
            .into(database.goals)
            .insertOnConflictUpdate(GoalDatabaseMapper.toCompanion(goal));
      }
      await _deleteConflicts(conflict.userId, conflict.entityId);
    });
  }

  Future<void> keepLocal({
    required String conflictId,
    required String deviceId,
  }) async {
    await database.transaction(() async {
      final conflict = await _load(conflictId);
      if (conflict == null) return;
      _requireGoal(conflict.entityType);

      final queued = await (database.select(database.syncOutbox)
            ..where(
              (table) =>
                  table.userId.equals(conflict.userId) &
                  table.entityType.equals(DriftGoalRepository.entityType) &
                  table.entityId.equals(conflict.entityId),
            )
            ..orderBy([
              (table) => OrderingTerm.asc(table.createdAt),
              (table) => OrderingTerm.asc(table.changeId),
            ])
            ..limit(1))
          .getSingleOrNull();
      if (queued == null) {
        throw StateError('目标冲突缺少本地待同步变更');
      }

      final version = conflict.serverVersion;
      if (version == null || version.isEmpty) {
        throw StateError('目标冲突缺少最新云端版本号');
      }

      final now = DateTime.now().toUtc().toIso8601String();
      await _deleteOutbox(conflict.userId, conflict.entityId);

      switch (queued.operation) {
        case 'delete':
          await _deleteGoal(conflict.userId, conflict.entityId);
          await database.into(database.syncOutbox).insert(
                db.SyncOutboxCompanion.insert(
                  changeId: _uuid.v4(),
                  userId: conflict.userId,
                  entityType: DriftGoalRepository.entityType,
                  entityId: conflict.entityId,
                  operation: 'delete',
                  baseServerVersion: version,
                  entitySchemaVersion: Value(queued.entitySchemaVersion),
                  clientModifiedAt: now,
                  createdAt: now,
                ),
              );
        case 'upsert':
          final row = await (database.select(database.goals)
                ..where(
                  (table) =>
                      table.userId.equals(conflict.userId) &
                      table.id.equals(conflict.entityId),
                ))
              .getSingleOrNull();
          if (row == null) throw StateError('本地目标已不存在，无法保留本地版本');

          final local = GoalDatabaseMapper.fromRow(row).copyWith(
            updatedAt: now,
            localVersion: row.localVersion + 1,
            serverVersion: version,
            modifiedByDevice: deviceId,
          );
          await database
              .into(database.goals)
              .insertOnConflictUpdate(GoalDatabaseMapper.toCompanion(local));
          await database.into(database.syncOutbox).insert(
                db.SyncOutboxCompanion.insert(
                  changeId: _uuid.v4(),
                  userId: conflict.userId,
                  entityType: DriftGoalRepository.entityType,
                  entityId: conflict.entityId,
                  operation: 'upsert',
                  baseServerVersion: version,
                  entitySchemaVersion: Value(queued.entitySchemaVersion),
                  clientModifiedAt: now,
                  payloadJson: Value(jsonEncode(GoalWireMapper.toPayload(local))),
                  createdAt: now,
                ),
              );
        default:
          throw StateError('不支持的目标冲突变更类型：${queued.operation}');
      }

      await _deleteConflicts(conflict.userId, conflict.entityId);
    });
  }

  Future<db.SyncConflict?> _load(String conflictId) =>
      (database.select(database.syncConflicts)
            ..where((table) => table.id.equals(conflictId)))
          .getSingleOrNull();

  Future<void> _deleteGoal(String userId, String goalId) =>
      (database.delete(database.goals)
            ..where(
              (table) =>
                  table.userId.equals(userId) & table.id.equals(goalId),
            ))
          .go();

  Future<void> _deleteOutbox(String userId, String goalId) =>
      (database.delete(database.syncOutbox)
            ..where(
              (table) =>
                  table.userId.equals(userId) &
                  table.entityType.equals(DriftGoalRepository.entityType) &
                  table.entityId.equals(goalId),
            ))
          .go();

  Future<void> _deleteConflicts(String userId, String goalId) =>
      (database.delete(database.syncConflicts)
            ..where(
              (table) =>
                  table.userId.equals(userId) &
                  table.entityType.equals(DriftGoalRepository.entityType) &
                  table.entityId.equals(goalId),
            ))
          .go();

  static void _requireGoal(String entityType) {
    if (entityType != DriftGoalRepository.entityType) {
      throw StateError('仅支持处理目标冲突');
    }
  }

  static Map<String, dynamic> _decodeObject(String raw) {
    final value = jsonDecode(raw);
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException('Goal conflict payload must be object');
  }
}
