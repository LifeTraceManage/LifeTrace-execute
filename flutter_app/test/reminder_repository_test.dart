import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/data/local/app_database.dart';
import 'package:lifetrace_execute/data/repository/reminder_repository.dart';
import 'package:lifetrace_execute/domain/reminder/execution_reminder.dart';

void main() {
  late AppDatabase database;
  late DriftReminderRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftReminderRepository(database);
  });

  tearDown(() async => database.close());

  test('schedule and reschedule keep one reminder and queue ordered revisions',
      () async {
    final firstTrigger =
        DateTime.now().toUtc().add(const Duration(days: 2));
    final secondTrigger = firstTrigger.add(const Duration(hours: 1));

    final first = await repository.schedule(
      userId: 'user-1',
      deviceId: 'device-1',
      subjectType: ReminderSubjectTypes.task,
      subjectId: 'task-1',
      triggerAt: firstTrigger.toIso8601String(),
      title: 'Task',
    );
    final second = await repository.schedule(
      userId: 'user-1',
      deviceId: 'device-1',
      subjectType: ReminderSubjectTypes.task,
      subjectId: 'task-1',
      triggerAt: secondTrigger.toIso8601String(),
      title: 'Task updated',
    );

    expect(second.id, first.id);
    expect(second.localVersion, 2);
    expect(second.fireKey, contains('task-1@'));

    final reminders = await database.select(database.reminders).get();
    expect(reminders, hasLength(1));
    expect(reminders.single.title, 'Task updated');

    final outbox = await database.select(database.syncOutbox).get();
    expect(outbox, hasLength(2));
    expect(
      outbox.every(
        (row) =>
            row.entityType == DriftReminderRepository.entityType &&
            row.entityId == first.id &&
            row.operation == 'upsert',
      ),
      isTrue,
    );

    final dependencies =
        jsonDecode(outbox.first.dependenciesJson) as List<dynamic>;
    expect(dependencies, hasLength(1));
    expect(dependencies.first['entityType'], 'execution.task');
    expect(dependencies.first['entityId'], 'task-1');
  });

  test('cancel persists explicit cancelled state and queues revision', () async {
    final reminder = await repository.schedule(
      userId: 'user-1',
      deviceId: 'device-1',
      subjectType: ReminderSubjectTypes.calendarEvent,
      subjectId: 'event-1',
      triggerAt:
          DateTime.now().toUtc().add(const Duration(days: 1)).toIso8601String(),
    );

    final cancelled = await repository.cancel(
      reminder: reminder,
      deviceId: 'device-1',
    );

    expect(cancelled.status, ExecutionReminderStatus.cancelled);
    final row = await database.select(database.reminders).getSingle();
    expect(row.status, 'cancelled');
    final outbox = await database.select(database.syncOutbox).get();
    expect(outbox, hasLength(2));
  });

  test('schedule rejects a past trigger', () async {
    await expectLater(
      repository.schedule(
        userId: 'user-1',
        deviceId: 'device-1',
        subjectType: ReminderSubjectTypes.task,
        subjectId: 'task-1',
        triggerAt: DateTime.now()
            .toUtc()
            .subtract(const Duration(minutes: 5))
            .toIso8601String(),
      ),
      throwsArgumentError,
    );
  });
}
