import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../local/app_database.dart' as db;
import '../repository/task_database_mapper.dart';
import '../repository/task_repository.dart';
import '../repository/task_wire_mapper.dart';

class TaskConflictResolver {
  TaskConflictResolver(this.database, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final db.AppDatabase database;
  final Uuid _uuid;

  Future<void> keepServer(String conflictId) async {
    await database.transaction(() async {
      final conflict = await (database.select(database.syncConflicts)
            ..where((table) => table.id.equals(conflictId)))
          .getSingleOrNull();
      if (conflict == null) return;
      if (conflict.entityType != DriftTaskRepository.entityType) {
        throw StateError('仅支持处理任务冲突');
      }

      await _deleteOutboxForEntity(
        conflict.userId,
        conflict.entityType,
        conflict.entityId,
      );

      if (conflict.serverDeleted) {
        await _deleteTask(conflict.userId, conflict.entityId);
      } else {
        final payloadJson = conflict.serverPayloadJson;
        final serverVersion = conflict.serverVersion;
        if (payloadJson == null || serverVersion == null) {
          throw StateError('服务器冲突结果缺少任务内容');
        }
        final task = TaskWireMapper.fromPayload(
          _decodeObject(payloadJson),
          serverVersion: serverVersion,
        );
        await database
            .into(database.tasks)
            .insertOnConflictUpdate(TaskDatabaseMapper.toRow(task));
      }

      await _deleteConflictsForEntity(
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
      final conflict = await (database.select(database.syncConflicts)
            ..where((table) => table.id.equals(conflictId)))
          .getSingleOrNull();
      if (conflict == null) return;
      if (conflict.entityType != DriftTaskRepository.entityType) {
        throw StateError('仅支持处理任务冲突');
      }

      final conflictedChange = await (database.select(database.syncOutbox)
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
      if (conflictedChange == null) {
        throw StateError('冲突缺少对应的本地待同步变更');
      }

      final serverVersion = conflict.serverVersion;
      if (serverVersion == null || serverVersion.isEmpty) {
        throw StateError('冲突缺少最新云端版本号');
      }

      final taskRow = await (database.select(database.tasks)
            ..where(
              (table) =>
                  table.userId.equals(conflict.userId) &
                  table.id.equals(conflict.entityId),
            ))
          .getSingleOrNull();
      final now = DateTime.now().toUtc().toIso8601String();

      await _deleteOutboxForEntity(
        conflict.userId,
        conflict.entityType,
        conflict.entityId,
      );

      switch (conflictedChange.operation) {
        case 'upsert':
          if (taskRow == null) {
            throw StateError('本地任务已不存在，无法选择保留本地版本');
          }
          final localTask = TaskDatabaseMapper.fromRow(taskRow);
          final rebasedTask = localTask.copyWith(
            updatedAt: now,
            localVersion: localTask.localVersion + 1,
            serverVersion: serverVersion,
            modifiedByDevice: deviceId,
          );
          await database
              .into(database.tasks)
              .insertOnConflictUpdate(TaskDatabaseMapper.toRow(rebasedTask));
          await database.into(database.syncOutbox).insert(
                db.SyncOutboxCompanion.insert(
                  changeId: _uuid.v4(),
                  userId: conflict.userId,
                  entityType: conflict.entityType,
                  entityId: conflict.entityId,
                  operation: 'upsert',
                  baseServerVersion: serverVersion,
                  entitySchemaVersion:
                      Value(conflictedChange.entitySchemaVersion),
                  clientModifiedAt: now,
                  payloadJson: Value(
                    jsonEncode(TaskWireMapper.toPayload(rebasedTask)),
                  ),
                  dependenciesJson: Value(_dependenciesJson(rebasedTask.projectId)),
                  createdAt: now,
                ),
              );
        case 'delete':
          await _deleteTask(conflict.userId, conflict.entityId);
          await database.into(database.syncOutbox).insert(
                db.SyncOutboxCompanion.insert(
                  changeId: _uuid.v4(),
                  userId: conflict.userId,
                  entityType: conflict.entityType,
                  entityId: conflict.entityId,
                  operation: 'delete',
                  baseServerVersion: serverVersion,
                  entitySchemaVersion:
                      Value(conflictedChange.entitySchemaVersion),
                  clientModifiedAt: now,
                  createdAt: now,
                ),
              );
        default:
          throw StateError('不支持的冲突变更类型：${conflictedChange.operation}');
      }

      await _deleteConflictsForEntity(
        conflict.userId,
        conflict.entityType,
        conflict.entityId,
      );
    });
  }

  Future<void> _deleteTask(String userId, String taskId) {
    return (database.delete(database.tasks)
          ..where(
            (table) => table.userId.equals(userId) & table.id.equals(taskId),
          ))
        .go();
  }

  Future<void> _deleteOutboxForEntity(
    String userId,
    String entityType,
    String entityId,
  ) {
    return (database.delete(database.syncOutbox)
          ..where(
            (table) =>
                table.userId.equals(userId) &
                table.entityType.equals(entityType) &
                table.entityId.equals(entityId),
          ))
        .go();
  }

  Future<void> _deleteConflictsForEntity(
    String userId,
    String entityType,
    String entityId,
  ) {
    return (database.delete(database.syncConflicts)
          ..where(
            (table) =>
                table.userId.equals(userId) &
                table.entityType.equals(entityType) &
                table.entityId.equals(entityId),
          ))
        .go();
  }

  static Map<String, dynamic> _decodeObject(String raw) {
    final value = jsonDecode(raw);
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException('Task conflict payload must be a JSON object');
  }

  static String _dependenciesJson(String? projectId) => jsonEncode([
        if (projectId != null)
          {'entityType': 'execution.project', 'entityId': projectId},
      ]);
}
