import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/data/local/app_database.dart';
import 'package:lifetrace_execute/data/repository/goal_repository.dart';
import 'package:lifetrace_execute/data/repository/project_repository.dart';
import 'package:lifetrace_execute/domain/goal/execution_goal.dart';

void main() {
  late AppDatabase database;
  late DriftGoalRepository goalRepository;
  late DriftProjectRepository projectRepository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    goalRepository = DriftGoalRepository(database);
    projectRepository = DriftProjectRepository(database);
  });

  tearDown(() async => database.close());

  test('goal create and complete are local-first and queue outbox', () async {
    final created = await goalRepository.createGoal(
      userId: 'user-1',
      deviceId: 'device-1',
      name: 'Finish thesis',
      description: 'Research',
      targetAt: '2026-12-31T23:59:59.000Z',
    );

    final completed = await goalRepository.updateGoal(
      goal: created,
      deviceId: 'device-2',
      status: ExecutionGoalStatus.completed,
    );

    expect(completed.localVersion, 2);
    expect(completed.completedAt, isNotNull);
    final goals = await database.select(database.goals).get();
    expect(goals, hasLength(1));
    expect(goals.single.status, 'completed');

    final outbox = await database.select(database.syncOutbox).get();
    expect(outbox, hasLength(2));
    expect(
      outbox.every(
        (row) =>
            row.entityType == DriftGoalRepository.entityType &&
            row.entityId == created.id &&
            row.operation == 'upsert',
      ),
      isTrue,
    );
  });

  test('deleting goal unlinks projects and queues both changes', () async {
    final goal = await goalRepository.createGoal(
      userId: 'user-1',
      deviceId: 'device-1',
      name: 'Ship LifeTrace',
    );
    final project = await projectRepository.createProject(
      userId: 'user-1',
      deviceId: 'device-1',
      title: 'Execute 1.0',
      goalId: goal.id,
    );
    await database.delete(database.syncOutbox).go();

    await goalRepository.deleteGoal(
      goal: goal,
      deviceId: 'device-2',
    );

    expect(await database.select(database.goals).get(), isEmpty);
    final projects = await database.select(database.projects).get();
    expect(projects.single.id, project.id);
    expect(projects.single.goalId, isNull);

    final outbox = await database.select(database.syncOutbox).get();
    expect(outbox, hasLength(2));
    expect(
      outbox.any(
        (row) =>
            row.entityType == DriftGoalRepository.entityType &&
            row.entityId == goal.id &&
            row.operation == 'delete',
      ),
      isTrue,
    );
    expect(
      outbox.any(
        (row) =>
            row.entityType == DriftProjectRepository.entityType &&
            row.entityId == project.id &&
            row.operation == 'upsert',
      ),
      isTrue,
    );
  });
}
