import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/data/local/app_database.dart';
import 'package:lifetrace_execute/data/repository/entity_link_repository.dart';
import 'package:lifetrace_execute/data/repository/task_repository.dart';
import 'package:lifetrace_execute/domain/task/execution_task.dart';

void main() {
  late AppDatabase database;
  late DriftTaskRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftTaskRepository(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('create/update/delete keep task and outbox in local-first parity', () async {
    final created = await repository.createTask(
      userId: 'user-1',
      deviceId: 'device-1',
      title: '  Flutter Task  ',
      description: 'local first',
      priority: ExecutionTaskPriority.high,
    );

    expect(created.title, 'Flutter Task');
    expect(await database.select(database.tasks).get(), hasLength(1));
    var outbox = await database.select(database.syncOutbox).get();
    expect(outbox, hasLength(1));
    expect(outbox.single.operation, 'upsert');
    expect(outbox.single.entityType, DriftTaskRepository.entityType);

    final completed = await repository.updateTask(
      task: created,
      deviceId: 'device-1',
      status: ExecutionTaskStatus.done,
    );

    expect(completed.localVersion, 2);
    expect(completed.completedAt, isNotNull);
    expect((await database.select(database.tasks).get()).single.status, 'done');
    outbox = await database.select(database.syncOutbox).get();
    expect(outbox, hasLength(2));

    await repository.deleteTask(userId: 'user-1', taskId: created.id);

    expect(await database.select(database.tasks).get(), isEmpty);
    outbox = await database.select(database.syncOutbox).get();
    expect(outbox, hasLength(3));
    expect(outbox.last.operation, 'delete');
  });

  test('deleting a task tombstones task links without deleting the child task',
      () async {
    final parent = await repository.createTask(
      userId: 'user-1',
      deviceId: 'device-1',
      title: 'Parent',
    );
    final child = await repository.createTask(
      userId: 'user-1',
      deviceId: 'device-1',
      title: 'Child',
    );
    final links = DriftEntityLinkRepository(database);
    await links.createLink(
      userId: 'user-1',
      deviceId: 'device-1',
      sourceType: DriftTaskRepository.entityType,
      sourceId: parent.id,
      targetType: DriftTaskRepository.entityType,
      targetId: child.id,
      relationType: 'subtask',
    );

    expect(await database.select(database.entityLinks).get(), hasLength(1));

    await database.delete(database.syncOutbox).go();
    await repository.deleteTask(userId: 'user-1', taskId: parent.id);

    final tasks = await database.select(database.tasks).get();
    expect(tasks.map((item) => item.id), contains(child.id));
    expect(tasks.map((item) => item.id), isNot(contains(parent.id)));
    expect(await database.select(database.entityLinks).get(), isEmpty);

    final outbox = await database.select(database.syncOutbox).get();
    expect(outbox, hasLength(2));
    expect(
      outbox.map((item) => item.entityType),
      containsAll(<String>[
        DriftEntityLinkRepository.entityType,
        DriftTaskRepository.entityType,
      ]),
    );
    expect(outbox.every((item) => item.operation == 'delete'), isTrue);
  });

}
