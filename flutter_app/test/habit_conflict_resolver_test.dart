import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/data/local/app_database.dart';
import 'package:lifetrace_execute/data/repository/habit_repository.dart';
import 'package:lifetrace_execute/data/sync/habit_conflict_resolver.dart';
import 'package:lifetrace_execute/domain/habit/habit.dart';

void main() {
  late AppDatabase database;
  late DriftHabitRepository repository;
  late HabitConflictResolver resolver;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftHabitRepository(database);
    resolver = HabitConflictResolver(database);
  });

  tearDown(() async => database.close());

  test('keepServer replaces local habit activity and clears blocked queue',
      () async {
    final local = await repository.createActivity(
      userId: 'user-1',
      deviceId: 'device-1',
      name: 'Local habit',
      activityType: HabitWireValues.activityDuration,
      unit: 'minutes',
      normalTarget: 30,
    );
    await (database.update(database.syncOutbox)
          ..where((table) => table.entityId.equals(local.id)))
        .write(const SyncOutboxCompanion(blocked: Value(true)));

    await database.into(database.syncConflicts).insert(
          SyncConflictsCompanion.insert(
            id: 'habit-server',
            userId: 'user-1',
            entityType: DriftHabitRepository.activityEntityType,
            entityId: local.id,
            createdAt: '2026-09-15T00:00:00Z',
            serverPayloadJson: Value(
              jsonEncode(_activityPayload(local.id, 'Cloud habit')),
            ),
            serverVersion: const Value('9'),
            reason: const Value('changed remotely'),
          ),
        );

    await resolver.keepServer('habit-server');

    final row = (await database.select(database.habitActivities).get()).single;
    expect(row.name, 'Cloud habit');
    expect(row.serverVersion, '9');
    expect(await database.select(database.syncOutbox).get(), isEmpty);
    expect(await database.select(database.syncConflicts).get(), isEmpty);
  });

  test('keepLocal rebases latest local habit log', () async {
    final activity = await repository.createActivity(
      userId: 'user-1',
      deviceId: 'device-1',
      name: 'Workout',
      activityType: HabitWireValues.activityCompletion,
      unit: 'done',
    );
    await (database.delete(database.syncOutbox)
          ..where(
            (table) =>
                table.entityType.equals(
                  DriftHabitRepository.activityEntityType,
                ),
          ))
        .go();

    final first = await repository.upsertDailyLog(
      userId: 'user-1',
      deviceId: 'device-1',
      activityId: activity.id,
      logDate: '2026-09-15',
      value: 0.5,
      status: HabitWireValues.logPartial,
    );
    await repository.upsertDailyLog(
      userId: 'user-1',
      deviceId: 'device-2',
      activityId: activity.id,
      logDate: '2026-09-15',
      value: 1,
      status: HabitWireValues.logCompleted,
      note: 'Latest local',
    );

    await (database.update(database.syncOutbox)
          ..where(
            (table) =>
                table.entityType.equals(DriftHabitRepository.logEntityType) &
                table.entityId.equals(first.id),
          ))
        .write(const SyncOutboxCompanion(blocked: Value(true)));

    final oldest = (await (database.select(database.syncOutbox)
              ..where(
                (table) =>
                    table.entityType.equals(
                      DriftHabitRepository.logEntityType,
                    ),
              )
              ..orderBy([(table) => OrderingTerm.asc(table.createdAt)]))
            .get())
        .first;

    await database.into(database.syncConflicts).insert(
          SyncConflictsCompanion.insert(
            id: 'habit-local',
            userId: 'user-1',
            entityType: DriftHabitRepository.logEntityType,
            entityId: first.id,
            createdAt: '2026-09-15T00:10:00Z',
            changeId: Value(oldest.changeId),
            serverPayloadJson: Value(
              jsonEncode(
                _logPayload(
                  first.id,
                  activity.id,
                  0.25,
                  HabitWireValues.logPartial,
                ),
              ),
            ),
            serverVersion: const Value('15'),
            reason: const Value('changed remotely'),
          ),
        );

    await resolver.keepLocal(
      conflictId: 'habit-local',
      deviceId: 'device-rebase',
    );

    final row = (await database.select(database.habitLogs).get()).single;
    expect(row.value, 1);
    expect(row.status, HabitWireValues.logCompleted);
    expect(row.note, 'Latest local');
    expect(row.serverVersion, '15');
    expect(row.modifiedByDevice, 'device-rebase');

    final outbox = await (database.select(database.syncOutbox)
          ..where(
            (table) =>
                table.entityType.equals(DriftHabitRepository.logEntityType),
          ))
        .get();
    expect(outbox, hasLength(1));
    expect(outbox.single.baseServerVersion, '15');
    final payload =
        jsonDecode(outbox.single.payloadJson!) as Map<String, dynamic>;
    expect(payload['status'], HabitWireValues.logCompleted);
    expect(payload['note'], 'Latest local');
    expect(await database.select(database.syncConflicts).get(), isEmpty);
  });
}

Map<String, dynamic> _activityPayload(String id, String name) => {
      'meta': {
        'id': id,
        'userId': 'user-1',
        'createdAt': '2026-09-15T00:00:00Z',
        'updatedAt': '2026-09-15T00:05:00Z',
        'deletedAt': null,
        'localVersion': 2,
        'serverVersion': null,
        'modifiedByDevice': 'cloud-device',
      },
      'name': name,
      'activityType': HabitWireValues.activityDuration,
      'unit': 'minutes',
      'minimumTarget': 10,
      'normalTarget': 45,
      'targetPeriod': 'daily',
      'targetDays': const [1, 2, 3, 4, 5],
      'icon': null,
      'color': null,
      'scheduleType': HabitWireValues.scheduleDaily,
      'startDate': '2026-09-15',
      'checkinMethod': HabitWireValues.checkinManual,
      'syncSource': null,
      'description': null,
      'isArchived': false,
    };

Map<String, dynamic> _logPayload(
  String id,
  String activityId,
  double value,
  String status,
) =>
    {
      'meta': {
        'id': id,
        'userId': 'user-1',
        'createdAt': '2026-09-15T00:00:00Z',
        'updatedAt': '2026-09-15T00:05:00Z',
        'deletedAt': null,
        'localVersion': 1,
        'serverVersion': null,
        'modifiedByDevice': 'cloud-device',
      },
      'activityId': activityId,
      'logDate': '2026-09-15',
      'value': value,
      'status': status,
      'note': 'Cloud',
      'metadata': null,
    };
