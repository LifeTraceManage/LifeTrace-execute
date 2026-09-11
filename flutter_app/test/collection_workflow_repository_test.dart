import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/data/local/app_database.dart';
import 'package:lifetrace_execute/data/repository/collection_workflow_repository.dart';
import 'package:lifetrace_execute/data/repository/entity_link_repository.dart';
import 'package:lifetrace_execute/data/repository/file_metadata_repository.dart';
import 'package:lifetrace_execute/data/repository/memo_repository.dart';
import 'package:lifetrace_execute/data/repository/project_repository.dart';
import 'package:lifetrace_execute/data/repository/task_repository.dart';
import 'package:lifetrace_execute/domain/collection/execution_file_metadata.dart';
import 'package:lifetrace_execute/domain/collection/execution_memo.dart';

void main() {
  late AppDatabase database;
  late DriftMemoRepository memos;
  late DriftProjectRepository projects;
  late CollectionWorkflowRepository workflow;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    memos = DriftMemoRepository(database);
    projects = DriftProjectRepository(database);
    workflow = CollectionWorkflowRepository(database);
  });

  tearDown(() async => database.close());

  test('convert memo to task persists task, archives memo and creates link', () async {
    final memo = await memos.createMemo(
      userId: 'user-1',
      deviceId: 'device-1',
      kind: ExecutionMemoKind.idea,
      title: 'Do the experiment',
      content: 'Run the robust MPC comparison.',
    );

    final result = await workflow.convertMemoToTask(
      memo: memo,
      deviceId: 'device-1',
    );

    expect(result.task.title, 'Do the experiment');
    expect(result.memo.status, ExecutionMemoStatus.archived);
    expect(result.link.relationType, 'created_from');
    expect(result.link.sourceType, DriftTaskRepository.entityType);
    expect(result.link.targetType, DriftMemoRepository.entityType);

    expect(await database.select(database.tasks).get(), hasLength(1));
    expect((await database.select(database.memos).get()).single.status, 'archived');
    expect(await database.select(database.entityLinks).get(), hasLength(1));

    final outbox = await database.select(database.syncOutbox).get();
    final taskChange = outbox.firstWhere(
      (row) => row.entityType == DriftTaskRepository.entityType,
    );
    final memoChange = outbox.lastWhere(
      (row) => row.entityType == DriftMemoRepository.entityType,
    );
    final linkChange = outbox.singleWhere(
      (row) => row.entityType == DriftEntityLinkRepository.entityType,
    );
    expect(taskChange.operation, 'upsert');
    expect(memoChange.operation, 'upsert');

    final dependencies = jsonDecode(linkChange.dependenciesJson) as List<dynamic>;
    expect(
      dependencies.any(
        (item) =>
            item is Map &&
            item['entityType'] == DriftTaskRepository.entityType &&
            item['entityId'] == result.task.id,
      ),
      isTrue,
    );
    expect(
      dependencies.any(
        (item) =>
            item is Map &&
            item['entityType'] == DriftMemoRepository.entityType &&
            item['entityId'] == memo.id,
      ),
      isTrue,
    );
  });

  test('delete memo tombstones links first and preserves shared file metadata', () async {
    final memo = await memos.createMemo(
      userId: 'user-1',
      deviceId: 'device-1',
      kind: ExecutionMemoKind.image,
      title: 'diagram.png',
      content: 'diagram.png',
    );
    const file = ExecutionFileMetadata(
      id: 'file-1',
      userId: 'user-1',
      originalName: 'diagram.png',
      mimeType: 'image/png',
      sizeBytes: 1024,
      sha256:
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      storageState: ExecutionFileStorageState.serverStored,
      createdByDevice: 'device-1',
      createdAt: '2026-09-11T00:00:00.000Z',
      updatedAt: '2026-09-11T00:00:00.000Z',
      localVersion: 1,
      serverVersion: '8',
      modifiedByDevice: 'device-1',
    );
    await database
        .into(database.fileRecords)
        .insert(FileMetadataDatabaseMapper.toRow(file));

    final links = DriftEntityLinkRepository(database);
    final attachment = await links.createLink(
      userId: 'user-1',
      deviceId: 'device-1',
      sourceType: DriftMemoRepository.entityType,
      sourceId: memo.id,
      targetType: DriftFileMetadataRepository.entityType,
      targetId: file.id,
      relationType: 'attachment',
    );
    final createdFrom = await links.createLink(
      userId: 'user-1',
      deviceId: 'device-1',
      sourceType: DriftTaskRepository.entityType,
      sourceId: 'task-1',
      targetType: DriftMemoRepository.entityType,
      targetId: memo.id,
      relationType: 'created_from',
    );

    await database.into(database.mediaUploads).insert(
          MediaUploadsCompanion.insert(
            id: 'upload-1',
            userId: 'user-1',
            memoId: memo.id,
            kind: ExecutionMemoKind.image.wireValue,
            localPath: '/tmp/diagram.png',
            originalName: 'diagram.png',
            mimeType: 'image/png',
            sizeBytes: 1024,
            sha256: file.sha256,
            status: 'server_stored',
            createdAt: '2026-09-11T00:00:00.000Z',
            updatedAt: '2026-09-11T00:00:00.000Z',
          ),
        );

    final result = await workflow.deleteMemoCascade(memo: memo);

    expect(result.deleted, isTrue);
    expect(result.deletedLinkCount, 2);
    expect(result.localPathsToDelete, ['/tmp/diagram.png']);
    expect(await database.select(database.memos).get(), isEmpty);
    expect(await database.select(database.entityLinks).get(), isEmpty);
    expect(await database.select(database.mediaUploads).get(), isEmpty);
    expect(await database.select(database.fileRecords).get(), hasLength(1));

    final outbox = await database.select(database.syncOutbox).get();
    final linkDeletes = outbox
        .where(
          (row) =>
              row.entityType == DriftEntityLinkRepository.entityType &&
              row.operation == 'delete' &&
              {attachment.id, createdFrom.id}.contains(row.entityId),
        )
        .toList();
    final memoDelete = outbox.singleWhere(
      (row) =>
          row.entityType == DriftMemoRepository.entityType &&
          row.entityId == memo.id &&
          row.operation == 'delete',
    );
    expect(linkDeletes, hasLength(2));
    expect(
      linkDeletes.every(
        (row) => row.createdAt.compareTo(memoDelete.createdAt) < 0,
      ),
      isTrue,
    );
    expect(
      outbox.where(
        (row) =>
            row.entityType == DriftFileMetadataRepository.entityType &&
            row.operation == 'delete',
      ),
      isEmpty,
    );
  });

  test('organize memo to project archives memo and creates belongs_to link', () async {
    final project = await projects.createProject(
      userId: 'user-1',
      deviceId: 'device-1',
      title: 'Research',
    );
    final memo = await memos.createMemo(
      userId: 'user-1',
      deviceId: 'device-1',
      kind: ExecutionMemoKind.text,
      content: 'Project note',
    );

    final link = await workflow.organizeMemoToProject(
      memo: memo,
      projectId: project.id,
      deviceId: 'device-1',
    );

    expect(link.relationType, 'belongs_to');
    expect(link.targetType, DriftProjectRepository.entityType);
    expect(link.targetId, project.id);
    expect((await database.select(database.memos).get()).single.status, 'archived');
  });
}
