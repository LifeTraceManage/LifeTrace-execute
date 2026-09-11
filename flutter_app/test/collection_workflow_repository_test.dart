import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/data/local/app_database.dart';
import 'package:lifetrace_execute/data/repository/collection_workflow_repository.dart';
import 'package:lifetrace_execute/data/repository/entity_link_repository.dart';
import 'package:lifetrace_execute/data/repository/memo_repository.dart';
import 'package:lifetrace_execute/data/repository/project_repository.dart';
import 'package:lifetrace_execute/data/repository/task_repository.dart';
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
