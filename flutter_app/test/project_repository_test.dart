import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/data/local/app_database.dart';
import 'package:lifetrace_execute/data/repository/project_repository.dart';
import 'package:lifetrace_execute/data/repository/task_repository.dart';
import 'package:lifetrace_execute/domain/project/execution_project.dart';

void main() {
  late AppDatabase database;
  late DriftProjectRepository projects;
  late DriftTaskRepository tasks;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    projects = DriftProjectRepository(database);
    tasks = DriftTaskRepository(database);
  });

  tearDown(() async => database.close());

  test('project CRUD persists locally and writes execution.project outbox', () async {
    final created = await projects.createProject(
      userId: 'user-1',
      deviceId: 'device-1',
      title: '  Real Project  ',
      description: 'local first',
      dueAt: '2026-10-01T00:00:00.000Z',
    );

    expect(created.title, 'Real Project');
    expect(await database.select(database.projects).get(), hasLength(1));
    var outbox = await database.select(database.syncOutbox).get();
    expect(outbox, hasLength(1));
    expect(outbox.single.entityType, DriftProjectRepository.entityType);

    final updated = await projects.updateProject(
      project: created,
      deviceId: 'device-1',
      status: ExecutionProjectStatus.paused,
    );
    expect(updated.localVersion, 2);
    expect(
      (await database.select(database.projects).get()).single.status,
      'paused',
    );

    await projects.deleteProject(project: updated, deviceId: 'device-1');
    expect(await database.select(database.projects).get(), isEmpty);
    outbox = await database.select(database.syncOutbox).get();
    expect(outbox.last.operation, 'delete');
    expect(outbox.last.entityType, DriftProjectRepository.entityType);
  });

  test('deleting a project unlinks its tasks and queues task update', () async {
    final project = await projects.createProject(
      userId: 'user-1',
      deviceId: 'device-1',
      title: 'Project with task',
    );
    final task = await tasks.createTask(
      userId: 'user-1',
      deviceId: 'device-1',
      title: 'Linked task',
      projectId: project.id,
    );

    await projects.deleteProject(project: project, deviceId: 'device-1');

    final storedTask = await (database.select(database.tasks)
          ..where((row) => row.id.equals(task.id)))
        .getSingle();
    expect(storedTask.projectId, isNull);

    final outbox = await database.select(database.syncOutbox).get();
    final taskChanges = outbox
        .where(
          (row) =>
              row.entityType == DriftTaskRepository.entityType &&
              row.entityId == task.id,
        )
        .toList();
    expect(taskChanges, hasLength(2));
    expect(taskChanges.last.payloadJson, contains('"projectId":null'));
  });
}
