import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/data/local/app_database.dart';
import 'package:lifetrace_execute/data/repository/habit_repository.dart';
import 'package:lifetrace_execute/domain/habit/habit.dart';

void main() {
  late AppDatabase database;
  late DriftHabitRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftHabitRepository(database);
  });

  tearDown(() async => database.close());

  test('activity create and update are local-first and queue outbox', () async {
    final created = await repository.createActivity(
      userId: 'user-1',
      deviceId: 'device-1',
      name: 'Read',
      activityType: HabitWireValues.activityDuration,
      unit: 'minutes',
      minimumTarget: 15,
      normalTarget: 30,
      targetPeriod: 'daily',
      targetDays: const [1, 2, 3, 4, 5],
    );

    final updated = await repository.updateActivity(
      activity: created,
      deviceId: 'device-2',
      normalTarget: 45,
      description: 'Paper reading',
    );

    expect(updated.id, created.id);
    expect(updated.localVersion, 2);
    final rows = await database.select(database.habitActivities).get();
    expect(rows, hasLength(1));
    expect(rows.single.normalTarget, 45);
    expect(rows.single.description, 'Paper reading');

    final outbox = await database.select(database.syncOutbox).get();
    expect(outbox, hasLength(2));
    expect(
      outbox.every(
        (row) =>
            row.entityType == DriftHabitRepository.activityEntityType &&
            row.entityId == created.id &&
            row.operation == 'upsert',
      ),
      isTrue,
    );
  });

  test('daily check-in reuses one row and queues revisions', () async {
    final activity = await repository.createActivity(
      userId: 'user-1',
      deviceId: 'device-1',
      name: 'Workout',
      activityType: HabitWireValues.activityCompletion,
      unit: 'done',
    );

    final first = await repository.upsertDailyLog(
      userId: 'user-1',
      deviceId: 'device-1',
      activityId: activity.id,
      logDate: '2026-09-15',
      value: 0.5,
      status: HabitWireValues.logPartial,
    );
    final second = await repository.upsertDailyLog(
      userId: 'user-1',
      deviceId: 'device-2',
      activityId: activity.id,
      logDate: '2026-09-15',
      value: 1,
      status: HabitWireValues.logCompleted,
    );

    expect(second.id, first.id);
    expect(second.localVersion, 2);
    final logs = await database.select(database.habitLogs).get();
    expect(logs, hasLength(1));
    expect(logs.single.value, 1);
    expect(logs.single.status, 'completed');

    final logOutbox = await (database.select(database.syncOutbox)
          ..where(
            (table) =>
                table.entityType.equals(DriftHabitRepository.logEntityType),
          ))
        .get();
    expect(logOutbox, hasLength(2));
  });
}
