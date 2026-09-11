import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../local/app_database.dart' as db;
import '../repository/project_database_mapper.dart';
import '../repository/project_repository.dart';
import '../repository/project_wire_mapper.dart';

class ProjectConflictResolver {
  ProjectConflictResolver(this.database, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  final db.AppDatabase database;
  final Uuid _uuid;

  Future<void> keepServer(String conflictId) async {
    await database.transaction(() async {
      final conflict = await (database.select(database.syncConflicts)
            ..where((table) => table.id.equals(conflictId)))
          .getSingleOrNull();
      if (conflict == null) return;
      if (conflict.entityType != DriftProjectRepository.entityType) {
        throw StateError('仅支持处理项目冲突');
      }

      await _deleteOutbox(conflict.userId, conflict.entityId);
      if (conflict.serverDeleted) {
        await _deleteProject(conflict.userId, conflict.entityId);
      } else {
        final payloadJson = conflict.serverPayloadJson;
        final serverVersion = conflict.serverVersion;
        if (payloadJson == null || serverVersion == null) {
          throw StateError('服务器冲突结果缺少项目内容');
        }
        final project = ProjectWireMapper.fromPayload(
          _decodeObject(payloadJson),
          serverVersion: serverVersion,
        );
        await database
            .into(database.projects)
            .insertOnConflictUpdate(ProjectDatabaseMapper.toRow(project));
      }
      await _deleteConflicts(conflict.userId, conflict.entityId);
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
      if (conflict.entityType != DriftProjectRepository.entityType) {
        throw StateError('仅支持处理项目冲突');
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

      final row = await (database.select(database.projects)
            ..where(
              (table) =>
                  table.userId.equals(conflict.userId) &
                  table.id.equals(conflict.entityId),
            ))
          .getSingleOrNull();
      final now = DateTime.now().toUtc().toIso8601String();

      await _deleteOutbox(conflict.userId, conflict.entityId);
      switch (conflictedChange.operation) {
        case 'upsert':
          if (row == null) {
            throw StateError('本地项目已不存在，无法选择保留本地版本');
          }
          final local = ProjectDatabaseMapper.fromRow(row);
          final rebased = local.copyWith(
            updatedAt: now,
            localVersion: local.localVersion + 1,
            serverVersion: serverVersion,
            modifiedByDevice: deviceId,
          );
          await database
              .into(database.projects)
              .insertOnConflictUpdate(ProjectDatabaseMapper.toRow(rebased));
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
                  payloadJson:
                      Value(jsonEncode(ProjectWireMapper.toPayload(rebased))),
                  createdAt: now,
                ),
              );
        case 'delete':
          await _deleteProject(conflict.userId, conflict.entityId);
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
          throw StateError(
            '不支持的项目冲突变更类型：${conflictedChange.operation}',
          );
      }
      await _deleteConflicts(conflict.userId, conflict.entityId);
    });
  }

  Future<void> _deleteOutbox(String userId, String projectId) {
    return (database.delete(database.syncOutbox)
          ..where(
            (table) =>
                table.userId.equals(userId) &
                table.entityType.equals(DriftProjectRepository.entityType) &
                table.entityId.equals(projectId),
          ))
        .go();
  }

  Future<void> _deleteConflicts(String userId, String projectId) {
    return (database.delete(database.syncConflicts)
          ..where(
            (table) =>
                table.userId.equals(userId) &
                table.entityType.equals(DriftProjectRepository.entityType) &
                table.entityId.equals(projectId),
          ))
        .go();
  }

  Future<void> _deleteProject(String userId, String projectId) {
    return (database.delete(database.projects)
          ..where(
            (table) =>
                table.userId.equals(userId) & table.id.equals(projectId),
          ))
        .go();
  }

  static Map<String, dynamic> _decodeObject(String raw) {
    final value = jsonDecode(raw);
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const FormatException('Project conflict payload must be an object');
  }
}
