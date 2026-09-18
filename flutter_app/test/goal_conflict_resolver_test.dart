import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/data/local/app_database.dart';
import 'package:lifetrace_execute/data/repository/goal_repository.dart';
import 'package:lifetrace_execute/data/sync/goal_conflict_resolver.dart';
import 'package:lifetrace_execute/domain/goal/execution_goal.dart';

void main() {
  late AppDatabase database;
  late DriftGoalRepository repository;
  late GoalConflictResolver resolver;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftGoalRepository(database);
    resolver = GoalConflictResolver(database);
  });

  tearDown(() async => database.close());

  test('keepServer replaces local goal and clears blocked queue', () async {
    final local = await repository.createGoal(
      userId: 'user-1',
      deviceId: 'device-1',
      name: 'Local goal',
    );
    await (database.update(database.syncOutbox)
          ..where((table) => table.entityId.equals(local.id)))
        .write(const SyncOutboxCompanion(blocked: Value(true)));

    await database.into(database.syncConflicts).insert(
          SyncConflictsCompanion.insert(
            id: 'goal-server',
            userId: 'user-1',
            entityType: DriftGoalRepository.entityType,
            entityId: local.id,
            createdAt: '2026-09-16T00:00:00Z',
            serverPayloadJson: Value(
              jsonEncode(_goalPayload(local.id, 'Cloud goal')),
            ),
            serverVersion: const Value('9'),
            reason: const Value('changed remotely'),
          ),
        );

    await resolver.keepServer('goal-server');

    final row = (await database.select(database.goals).get()).single;
    expect(row.name, 'Cloud goal');
    expect(row.serverVersion, '9');
    expect(await database.select(database.syncOutbox).get(), isEmpty);
    expect(await database.select(database.syncConflicts).get(), isEmpty);
  });

  test('keepLocal rebases latest local goal against server version', () async {
    final first = await repository.createGoal(
      userId: 'user-1',
      deviceId: 'device-1',
      name: 'First',
    );
    final latest = await repository.updateGoal(
      goal: first,
      deviceId: 'device-2',
      name: 'Latest local',
      status: ExecutionGoalStatus.paused,
    );

    await (database.update(database.syncOutbox)
          ..where((table) => table.entityId.equals(first.id)))
        .write(const SyncOutboxCompanion(blocked: Value(true)));

    final oldest = (await (database.select(database.syncOutbox)
              ..where((table) => table.entityId.equals(first.id))
              ..orderBy([(table) => OrderingTerm.asc(table.createdAt)]))
            .get())
        .first;

    await database.into(database.syncConflicts).insert(
          SyncConflictsCompanion.insert(
            id: 'goal-local',
            userId: 'user-1',
            entityType: DriftGoalRepository.entityType,
            entityId: first.id,
            createdAt: '2026-09-16T00:10:00Z',
            changeId: Value(oldest.changeId),
            serverPayloadJson: Value(
              jsonEncode(_goalPayload(first.id, 'Cloud version')),
            ),
            serverVersion: const Value('15'),
            reason: const Value('changed remotely'),
          ),
        );

    await resolver.keepLocal(
      conflictId: 'goal-local',
      deviceId: 'device-rebase',
    );

    final row = (await database.select(database.goals).get()).single;
    expect(row.name, latest.name);
    expect(row.status, 'paused');
    expect(row.serverVersion, '15');
    expect(row.modifiedByDevice, 'device-rebase');
    expect(row.localVersion, latest.localVersion + 1);

    final outbox = await database.select(database.syncOutbox).get();
    expect(outbox, hasLength(1));
    expect(outbox.single.baseServerVersion, '15');
    final payload =
        jsonDecode(outbox.single.payloadJson!) as Map<String, dynamic>;
    expect(payload['name'], 'Latest local');
    expect(payload['status'], 'paused');
    expect(await database.select(database.syncConflicts).get(), isEmpty);
  });
}

Map<String, dynamic> _goalPayload(String id, String name) => {
      'meta': {
        'id': id,
        'userId': 'user-1',
        'createdAt': '2026-09-16T00:00:00Z',
        'updatedAt': '2026-09-16T00:05:00Z',
        'deletedAt': null,
        'localVersion': 2,
        'serverVersion': null,
        'modifiedByDevice': 'cloud-device',
      },
      'name': name,
      'description': 'Cloud',
      'status': 'active',
      'targetAt': null,
      'color': '#49715d',
      'icon': 'target',
      'sortOrder': 0,
      'completedAt': null,
    };
