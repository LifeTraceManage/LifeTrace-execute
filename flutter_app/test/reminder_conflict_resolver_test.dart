import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/data/local/app_database.dart';
import 'package:lifetrace_execute/data/repository/reminder_repository.dart';
import 'package:lifetrace_execute/data/sync/reminder_conflict_resolver.dart';

void main() {
  late AppDatabase database;
  late DriftReminderRepository repository;
  late ReminderConflictResolver resolver;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftReminderRepository(database);
    resolver = ReminderConflictResolver(database);
  });

  tearDown(() => database.close());

  test('keepServer replaces local reminder and clears conflicting outbox', () async {
    final local = await repository.schedule(
      userId: 'user-1',
      deviceId: 'local-device',
      subjectType: ReminderSubjectTypes.task,
      subjectId: 'task-1',
      triggerAt:
          DateTime.now().toUtc().add(const Duration(days: 2)).toIso8601String(),
      title: 'Local reminder',
    );
    await (database.update(database.syncOutbox)
          ..where((table) => table.entityId.equals(local.id)))
        .write(const SyncOutboxCompanion(blocked: Value(true)));

    await database.into(database.syncConflicts).insert(
          SyncConflictsCompanion.insert(
            id: 'reminder-conflict-server',
            userId: 'user-1',
            entityType: DriftReminderRepository.entityType,
            entityId: local.id,
            createdAt: '2026-09-11T00:00:00.000Z',
            changeId: const Value('change-1'),
            clientBaseServerVersion: const Value('0'),
            serverPayloadJson: Value(
              jsonEncode(_payload(local.id, title: 'Cloud reminder')),
            ),
            serverVersion: const Value('8'),
            reason: const Value('changed remotely'),
          ),
        );

    await resolver.keepServer('reminder-conflict-server');

    final reminder = (await database.select(database.reminders).get()).single;
    expect(reminder.title, 'Cloud reminder');
    expect(reminder.serverVersion, '8');
    expect(await database.select(database.syncOutbox).get(), isEmpty);
    expect(await database.select(database.syncConflicts).get(), isEmpty);
  });

  test('keepLocal rebases reminder and preserves subject dependency', () async {
    final first = await repository.schedule(
      userId: 'user-1',
      deviceId: 'local-device',
      subjectType: ReminderSubjectTypes.task,
      subjectId: 'task-1',
      triggerAt:
          DateTime.now().toUtc().add(const Duration(days: 2)).toIso8601String(),
      title: 'First local',
    );
    await repository.schedule(
      userId: 'user-1',
      deviceId: 'local-device',
      subjectType: ReminderSubjectTypes.task,
      subjectId: 'task-1',
      triggerAt:
          DateTime.now().toUtc().add(const Duration(days: 3)).toIso8601String(),
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
            id: 'reminder-conflict-local',
            userId: 'user-1',
            entityType: DriftReminderRepository.entityType,
            entityId: first.id,
            createdAt: '2026-09-11T00:00:00.000Z',
            changeId: Value(oldest.changeId),
            clientBaseServerVersion: const Value('0'),
            serverPayloadJson:
                Value(jsonEncode(_payload(first.id, title: 'Cloud reminder'))),
            serverVersion: const Value('15'),
            reason: const Value('changed remotely'),
          ),
        );

    await resolver.keepLocal(
      conflictId: 'reminder-conflict-local',
      deviceId: 'device-rebase',
    );

    final reminder = (await database.select(database.reminders).get()).single;
    expect(reminder.title, 'Latest local');
    expect(reminder.serverVersion, '15');
    expect(reminder.modifiedByDevice, 'device-rebase');

    final outbox = await database.select(database.syncOutbox).get();
    expect(outbox, hasLength(1));
    expect(outbox.single.baseServerVersion, '15');
    final dependencies =
        jsonDecode(outbox.single.dependenciesJson) as List<dynamic>;
    expect(dependencies.single['entityType'], 'execution.task');
    expect(dependencies.single['entityId'], 'task-1');
    expect(await database.select(database.syncConflicts).get(), isEmpty);
  });
}

Map<String, dynamic> _payload(
  String id, {
  required String title,
}) =>
    {
      'meta': {
        'id': id,
        'userId': 'user-1',
        'createdAt': '2026-09-10T00:00:00.000Z',
        'updatedAt': '2026-09-11T00:00:00.000Z',
        'deletedAt': null,
        'localVersion': 2,
        'serverVersion': null,
        'modifiedByDevice': 'cloud-device',
      },
      'subjectType': 'task',
      'subjectId': 'task-1',
      'triggerAt': '2026-09-12T01:30:00.000Z',
      'status': 'scheduled',
      'fireKey': 'task-1@2026-09-12T01:30:00.000Z',
      'snoozedUntil': null,
      'lastFiredAt': null,
      'title': title,
      'body': 'Cloud body',
    };
