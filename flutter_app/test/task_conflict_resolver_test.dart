import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/data/local/app_database.dart';
import 'package:lifetrace_execute/data/repository/task_repository.dart';
import 'package:lifetrace_execute/data/sync/task_conflict_resolver.dart';

void main() {
  late AppDatabase database;
  late DriftTaskRepository repository;
  late TaskConflictResolver resolver;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftTaskRepository(database);
    resolver = TaskConflictResolver(database);
  });

  tearDown(() => database.close());

  test('keepServer replaces local task and clears conflicting queue', () async {
    final local = await repository.createTask(
      userId: 'user-1',
      deviceId: 'local-device',
      title: 'Local title',
    );
    await (database.update(database.syncOutbox)
          ..where((table) => table.entityId.equals(local.id)))
        .write(const SyncOutboxCompanion(blocked: Value(true)));

    await database.into(database.syncConflicts).insert(
          SyncConflictsCompanion.insert(
            id: 'conflict-server',
            userId: 'user-1',
            entityType: DriftTaskRepository.entityType,
            entityId: local.id,
            createdAt: '2026-09-11T00:00:00.000Z',
            changeId: const Value('change-1'),
            clientBaseServerVersion: const Value('0'),
            serverPayloadJson: Value(jsonEncode(_payload(local.id, 'Cloud title'))),
            serverVersion: const Value('8'),
            reason: const Value('changed remotely'),
          ),
        );

    await resolver.keepServer('conflict-server');

    final task = (await database.select(database.tasks).get()).single;
    expect(task.title, 'Cloud title');
    expect(task.serverVersion, '8');
    expect(await database.select(database.syncOutbox).get(), isEmpty);
    expect(await database.select(database.syncConflicts).get(), isEmpty);
  });

  test('keepServer honors remote deletion', () async {
    final local = await repository.createTask(
      userId: 'user-1',
      deviceId: 'local-device',
      title: 'Delete me remotely',
    );
    await database.into(database.syncConflicts).insert(
          SyncConflictsCompanion.insert(
            id: 'conflict-delete',
            userId: 'user-1',
            entityType: DriftTaskRepository.entityType,
            entityId: local.id,
            createdAt: '2026-09-11T00:00:00.000Z',
            changeId: const Value('change-delete'),
            clientBaseServerVersion: const Value('1'),
            serverVersion: const Value('2'),
            serverDeleted: const Value(true),
            reason: const Value('deleted remotely'),
          ),
        );

    await resolver.keepServer('conflict-delete');

    expect(await database.select(database.tasks).get(), isEmpty);
    expect(await database.select(database.syncOutbox).get(), isEmpty);
    expect(await database.select(database.syncConflicts).get(), isEmpty);
  });

  test('keepLocal rebases current local state onto latest server version', () async {
    final first = await repository.createTask(
      userId: 'user-1',
      deviceId: 'local-device',
      title: 'First local',
    );
    await repository.updateTask(
      task: first,
      deviceId: 'local-device',
      title: 'Latest local',
    );
    await (database.update(database.syncOutbox)
          ..where((table) => table.entityId.equals(first.id)))
        .write(const SyncOutboxCompanion(blocked: Value(true)));

    final oldest = (await (database.select(database.syncOutbox)
              ..orderBy([(table) => OrderingTerm.asc(table.createdAt)]))
            .get())
        .first;
    await database.into(database.syncConflicts).insert(
          SyncConflictsCompanion.insert(
            id: 'conflict-local',
            userId: 'user-1',
            entityType: DriftTaskRepository.entityType,
            entityId: first.id,
            createdAt: '2026-09-11T00:00:00.000Z',
            changeId: Value(oldest.changeId),
            clientBaseServerVersion: const Value('0'),
            serverPayloadJson: Value(jsonEncode(_payload(first.id, 'Cloud'))),
            serverVersion: const Value('15'),
            reason: const Value('changed remotely'),
          ),
        );

    await resolver.keepLocal(
      conflictId: 'conflict-local',
      deviceId: 'device-rebase',
    );

    final task = (await database.select(database.tasks).get()).single;
    expect(task.title, 'Latest local');
    expect(task.serverVersion, '15');
    expect(task.modifiedByDevice, 'device-rebase');
    final outbox = await database.select(database.syncOutbox).get();
    expect(outbox, hasLength(1));
    expect(outbox.single.operation, 'upsert');
    expect(outbox.single.baseServerVersion, '15');
    expect(outbox.single.blocked, isFalse);
    expect(jsonDecode(outbox.single.payloadJson!)['title'], 'Latest local');
    expect(await database.select(database.syncConflicts).get(), isEmpty);
  });
}

Map<String, dynamic> _payload(String id, String title) => {
      'meta': {
        'id': id,
        'userId': 'user-1',
        'createdAt': '2026-09-10T00:00:00.000Z',
        'updatedAt': '2026-09-11T00:00:00.000Z',
        'deletedAt': null,
        'localVersion': 3,
        'serverVersion': null,
        'modifiedByDevice': 'cloud-device',
      },
      'title': title,
      'description': null,
      'projectId': null,
      'status': 'todo',
      'priority': 'normal',
      'dueAt': null,
      'scheduledAt': null,
      'completedAt': null,
    };
