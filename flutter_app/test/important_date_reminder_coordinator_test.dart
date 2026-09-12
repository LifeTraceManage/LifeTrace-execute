import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/data/local/app_database.dart';
import 'package:lifetrace_execute/data/repository/important_date_repository.dart';
import 'package:lifetrace_execute/data/repository/reminder_repository.dart';
import 'package:lifetrace_execute/data/sync/important_date_reminder_coordinator.dart';
import 'package:lifetrace_execute/domain/important_date/execution_important_date.dart';

void main() {
  late AppDatabase database;
  late DriftImportantDateRepository importantDates;
  late DriftReminderRepository reminders;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    importantDates = DriftImportantDateRepository(database);
    reminders = DriftReminderRepository(database);
  });

  tearDown(() async => database.close());

  test('fired yearly reminder is renewed in place for the next occurrence',
      () async {
    final sourceDate = DateTime.now().add(const Duration(days: 35));
    final importantDate = await importantDates.createImportantDate(
      userId: 'user-1',
      deviceId: 'device-1',
      title: 'Anniversary',
      repeat: ImportantDateRepeat.yearly,
      kind: ImportantDateKind.anniversary,
      calendar: ImportantDateCalendar.solar,
      solarDate: sourceDate,
    );
    final reminder = await reminders.schedule(
      userId: 'user-1',
      deviceId: 'device-1',
      subjectType: ReminderSubjectTypes.importantDate,
      subjectId: importantDate.id,
      triggerAt: DateTime.now()
          .toUtc()
          .add(const Duration(hours: 2))
          .toIso8601String(),
      title: importantDate.title,
    );

    await database.delete(database.syncOutbox).go();
    final firedAt =
        DateTime.now().toUtc().subtract(const Duration(hours: 1));
    await (database.update(database.reminders)
          ..where((table) => table.id.equals(reminder.id)))
        .write(
      RemindersCompanion(
        triggerAt: Value(firedAt.toIso8601String()),
        status: const Value('fired'),
        lastFiredAt: Value(firedAt.toIso8601String()),
        updatedAt: Value(firedAt.toIso8601String()),
        serverVersion: const Value('12'),
      ),
    );

    final changed = await ImportantDateReminderCoordinator(
      importantDates: importantDates,
      reminders: reminders,
    ).reconcileYearlyFired(
      userId: 'user-1',
      deviceId: 'device-2',
    );

    expect(changed, 1);
    final rows = await database.select(database.reminders).get();
    expect(rows, hasLength(1));
    expect(rows.single.id, reminder.id);
    expect(rows.single.status, 'scheduled');
    expect(rows.single.serverVersion, '12');
    expect(
      DateTime.parse(rows.single.triggerAt).isAfter(DateTime.now().toUtc()),
      isTrue,
    );

    final outbox = await database.select(database.syncOutbox).get();
    expect(outbox, hasLength(1));
    expect(outbox.single.entityType, DriftReminderRepository.entityType);
    expect(outbox.single.entityId, reminder.id);
    expect(outbox.single.baseServerVersion, '12');
  });

  test('cancelled yearly reminder is not resurrected', () async {
    final sourceDate = DateTime.now().add(const Duration(days: 20));
    final importantDate = await importantDates.createImportantDate(
      userId: 'user-1',
      deviceId: 'device-1',
      title: 'No reminder',
      repeat: ImportantDateRepeat.yearly,
      kind: ImportantDateKind.other,
      calendar: ImportantDateCalendar.solar,
      solarDate: sourceDate,
    );
    final reminder = await reminders.schedule(
      userId: 'user-1',
      deviceId: 'device-1',
      subjectType: ReminderSubjectTypes.importantDate,
      subjectId: importantDate.id,
      triggerAt: DateTime.now()
          .toUtc()
          .add(const Duration(hours: 3))
          .toIso8601String(),
    );
    await reminders.cancel(reminder: reminder, deviceId: 'device-1');
    await database.delete(database.syncOutbox).go();

    final changed = await ImportantDateReminderCoordinator(
      importantDates: importantDates,
      reminders: reminders,
    ).reconcileYearlyFired(
      userId: 'user-1',
      deviceId: 'device-2',
    );

    expect(changed, 0);
    expect(await database.select(database.syncOutbox).get(), isEmpty);
  });
}
