import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/collection/entity_link.dart';
import '../../domain/collection/execution_memo.dart';
import '../../domain/task/execution_task.dart';
import '../local/app_database.dart' as db;
import 'entity_link_repository.dart';
import 'memo_repository.dart';
import 'task_database_mapper.dart';
import 'task_repository.dart';
import 'task_wire_mapper.dart';

class CollectionConversionResult {
  const CollectionConversionResult({
    required this.task,
    required this.memo,
    required this.link,
  });

  final ExecutionTask task;
  final ExecutionMemo memo;
  final ExecutionEntityLink link;
}

class CollectionDeleteResult {
  const CollectionDeleteResult({
    required this.deleted,
    required this.deletedLinkCount,
    required this.localPathsToDelete,
  });

  final bool deleted;
  final int deletedLinkCount;
  final List<String> localPathsToDelete;
}

class CollectionWorkflowRepository {
  CollectionWorkflowRepository(this.database, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  final db.AppDatabase database;
  final Uuid _uuid;

  Future<CollectionConversionResult> convertMemoToTask({
    required ExecutionMemo memo,
    required String deviceId,
  }) async {
    if (!memo.isInbox) {
      throw StateError('只有 Inbox 内容可以转成任务');
    }

    final nowValue = DateTime.now().toUtc();
    final now = nowValue.toIso8601String();
    final linkTime =
        nowValue.add(const Duration(milliseconds: 1)).toIso8601String();
    final title = _taskTitle(memo);
    final task = ExecutionTask(
      id: _uuid.v4(),
      userId: memo.userId,
      title: title,
      description: memo.content,
      status: ExecutionTaskStatus.todo,
      priority: ExecutionTaskPriority.normal,
      createdAt: now,
      updatedAt: now,
      localVersion: 1,
      modifiedByDevice: deviceId,
    );
    final archivedMemo = memo.copyWith(
      status: ExecutionMemoStatus.archived,
      updatedAt: now,
      localVersion: memo.localVersion + 1,
      modifiedByDevice: deviceId,
    );
    final link = ExecutionEntityLink(
      id: _uuid.v4(),
      userId: memo.userId,
      sourceType: DriftTaskRepository.entityType,
      sourceId: task.id,
      targetType: DriftMemoRepository.entityType,
      targetId: memo.id,
      relationType: 'created_from',
      metadata: const {'workflow': 'collection.convert_to_task'},
      createdAt: linkTime,
      updatedAt: linkTime,
      localVersion: 1,
      modifiedByDevice: deviceId,
    );

    await database.transaction(() async {
      await database
          .into(database.tasks)
          .insert(TaskDatabaseMapper.toRow(task));
      await database
          .into(database.memos)
          .insertOnConflictUpdate(MemoDatabaseMapper.toRow(archivedMemo));
      await database
          .into(database.entityLinks)
          .insert(EntityLinkDatabaseMapper.toRow(link));

      await database.into(database.syncOutbox).insert(
            db.SyncOutboxCompanion.insert(
              changeId: _uuid.v4(),
              userId: task.userId,
              entityType: DriftTaskRepository.entityType,
              entityId: task.id,
              operation: 'upsert',
              baseServerVersion: '0',
              clientModifiedAt: now,
              payloadJson: Value(
                jsonEncode(TaskWireMapper.toPayload(task)),
              ),
              createdAt: now,
            ),
          );

      await database.into(database.syncOutbox).insert(
            db.SyncOutboxCompanion.insert(
              changeId: _uuid.v4(),
              userId: archivedMemo.userId,
              entityType: DriftMemoRepository.entityType,
              entityId: archivedMemo.id,
              operation: 'upsert',
              baseServerVersion: archivedMemo.serverVersion ?? '0',
              clientModifiedAt: now,
              payloadJson: Value(
                jsonEncode(MemoWireMapper.toPayload(archivedMemo)),
              ),
              createdAt: now,
            ),
          );

      await database.into(database.syncOutbox).insert(
            db.SyncOutboxCompanion.insert(
              changeId: _uuid.v4(),
              userId: link.userId,
              entityType: DriftEntityLinkRepository.entityType,
              entityId: link.id,
              operation: 'upsert',
              baseServerVersion: '0',
              clientModifiedAt: linkTime,
              payloadJson: Value(
                jsonEncode(EntityLinkWireMapper.toPayload(link)),
              ),
              dependenciesJson: Value(
                jsonEncode([
                  {
                    'entityType': DriftTaskRepository.entityType,
                    'entityId': task.id,
                  },
                  {
                    'entityType': DriftMemoRepository.entityType,
                    'entityId': memo.id,
                  },
                ]),
              ),
              createdAt: linkTime,
            ),
          );
    });

    return CollectionConversionResult(
      task: task,
      memo: archivedMemo,
      link: link,
    );
  }

  Future<ExecutionEntityLink> organizeMemoToProject({
    required ExecutionMemo memo,
    required String projectId,
    required String deviceId,
  }) async {
    if (!memo.isInbox) {
      throw StateError('只有 Inbox 内容可以整理到项目');
    }
    final project = await (database.select(database.projects)
          ..where(
            (table) =>
                table.userId.equals(memo.userId) &
                table.id.equals(projectId),
          ))
        .getSingleOrNull();
    if (project == null) throw StateError('目标项目不存在');

    final nowValue = DateTime.now().toUtc();
    final now = nowValue.toIso8601String();
    final linkTime =
        nowValue.add(const Duration(milliseconds: 1)).toIso8601String();
    final archivedMemo = memo.copyWith(
      status: ExecutionMemoStatus.archived,
      updatedAt: now,
      localVersion: memo.localVersion + 1,
      modifiedByDevice: deviceId,
    );
    final link = ExecutionEntityLink(
      id: _uuid.v4(),
      userId: memo.userId,
      sourceType: DriftMemoRepository.entityType,
      sourceId: memo.id,
      targetType: 'execution.project',
      targetId: projectId,
      relationType: 'belongs_to',
      metadata: const {'workflow': 'collection.organize_to_project'},
      createdAt: linkTime,
      updatedAt: linkTime,
      localVersion: 1,
      modifiedByDevice: deviceId,
    );

    await database.transaction(() async {
      await database
          .into(database.memos)
          .insertOnConflictUpdate(MemoDatabaseMapper.toRow(archivedMemo));
      await database
          .into(database.entityLinks)
          .insert(EntityLinkDatabaseMapper.toRow(link));

      await database.into(database.syncOutbox).insert(
            db.SyncOutboxCompanion.insert(
              changeId: _uuid.v4(),
              userId: memo.userId,
              entityType: DriftMemoRepository.entityType,
              entityId: memo.id,
              operation: 'upsert',
              baseServerVersion: memo.serverVersion ?? '0',
              clientModifiedAt: now,
              payloadJson: Value(
                jsonEncode(MemoWireMapper.toPayload(archivedMemo)),
              ),
              createdAt: now,
            ),
          );
      await database.into(database.syncOutbox).insert(
            db.SyncOutboxCompanion.insert(
              changeId: _uuid.v4(),
              userId: memo.userId,
              entityType: DriftEntityLinkRepository.entityType,
              entityId: link.id,
              operation: 'upsert',
              baseServerVersion: '0',
              clientModifiedAt: linkTime,
              payloadJson: Value(
                jsonEncode(EntityLinkWireMapper.toPayload(link)),
              ),
              dependenciesJson: Value(
                jsonEncode([
                  {
                    'entityType': DriftMemoRepository.entityType,
                    'entityId': memo.id,
                  },
                  {
                    'entityType': 'execution.project',
                    'entityId': projectId,
                  },
                ]),
              ),
              createdAt: linkTime,
            ),
          );
    });

    return link;
  }

  Future<CollectionDeleteResult> deleteMemoCascade({
    required ExecutionMemo memo,
  }) async {
    final existing = await (database.select(database.memos)
          ..where(
            (table) =>
                table.userId.equals(memo.userId) &
                table.id.equals(memo.id),
          ))
        .getSingleOrNull();
    if (existing == null) {
      return const CollectionDeleteResult(
        deleted: false,
        deletedLinkCount: 0,
        localPathsToDelete: <String>[],
      );
    }

    final links = await (database.select(database.entityLinks)
          ..where(
            (table) =>
                table.userId.equals(memo.userId) &
                ((table.sourceType.equals(DriftMemoRepository.entityType) &
                        table.sourceId.equals(memo.id)) |
                    (table.targetType.equals(DriftMemoRepository.entityType) &
                        table.targetId.equals(memo.id))),
          ))
        .get();
    final uploads = await (database.select(database.mediaUploads)
          ..where(
            (table) =>
                table.userId.equals(memo.userId) &
                table.memoId.equals(memo.id),
          ))
        .get();

    final baseTime = DateTime.now().toUtc();
    final localPaths = uploads
        .map((row) => row.localPath)
        .where((path) => path.isNotEmpty)
        .toSet()
        .toList(growable: false);

    await database.transaction(() async {
      for (var index = 0; index < links.length; index++) {
        final link = links[index];
        final time = baseTime
            .add(Duration(milliseconds: index))
            .toIso8601String();
        await database.into(database.syncOutbox).insert(
              db.SyncOutboxCompanion.insert(
                changeId: _uuid.v4(),
                userId: memo.userId,
                entityType: DriftEntityLinkRepository.entityType,
                entityId: link.id,
                operation: 'delete',
                baseServerVersion: link.serverVersion ?? '0',
                clientModifiedAt: time,
                createdAt: time,
              ),
            );
      }

      final memoDeleteTime = baseTime
          .add(Duration(milliseconds: links.length + 1))
          .toIso8601String();
      await database.into(database.syncOutbox).insert(
            db.SyncOutboxCompanion.insert(
              changeId: _uuid.v4(),
              userId: memo.userId,
              entityType: DriftMemoRepository.entityType,
              entityId: memo.id,
              operation: 'delete',
              baseServerVersion: existing.serverVersion ?? '0',
              clientModifiedAt: memoDeleteTime,
              createdAt: memoDeleteTime,
            ),
          );

      await (database.delete(database.entityLinks)
            ..where(
              (table) =>
                  table.userId.equals(memo.userId) &
                  ((table.sourceType.equals(DriftMemoRepository.entityType) &
                          table.sourceId.equals(memo.id)) |
                      (table.targetType.equals(DriftMemoRepository.entityType) &
                          table.targetId.equals(memo.id))),
            ))
          .go();
      await (database.delete(database.mediaUploads)
            ..where(
              (table) =>
                  table.userId.equals(memo.userId) &
                  table.memoId.equals(memo.id),
            ))
          .go();
      await (database.delete(database.memos)
            ..where(
              (table) =>
                  table.userId.equals(memo.userId) &
                  table.id.equals(memo.id),
            ))
          .go();
    });

    return CollectionDeleteResult(
      deleted: true,
      deletedLinkCount: links.length,
      localPathsToDelete: localPaths,
    );
  }

  static String _taskTitle(ExecutionMemo memo) {
    final explicit = memo.title?.trim();
    if (explicit != null && explicit.isNotEmpty) return explicit;
    final singleLine = memo.content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (singleLine.length <= 60) return singleLine;
    return '${singleLine.substring(0, 60)}…';
  }
}
