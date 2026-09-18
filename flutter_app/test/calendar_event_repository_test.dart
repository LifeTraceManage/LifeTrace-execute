import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/data/local/app_database.dart';
import 'package:lifetrace_execute/data/repository/calendar_event_repository.dart';

void main() {
  late AppDatabase database;
  late DriftCalendarEventRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftCalendarEventRepository(database);
  });

  tearDown(() async => database.close());

  test('calendar event CRUD is local-first and writes outbox', () async {
    final created = await repository.createEvent(
      userId: 'user-1',
      deviceId: 'device-1',
      title: 'Project meeting',
      startAt: '2026-09-11T06:30:00.000Z',
      endAt: '2026-09-11T07:30:00.000Z',
      location: 'Room A',
    );

    expect(await database.select(database.calendarEvents).get(), hasLength(1));
    var outbox = await database.select(database.syncOutbox).get();
    expect(outbox.single.entityType, DriftCalendarEventRepository.entityType);
    expect(outbox.single.operation, 'upsert');

    final updated = await repository.updateEvent(
      event: created,
      deviceId: 'device-1',
      title: 'Updated meeting',
      allDay: true,
    );
    expect(updated.localVersion, 2);
    expect(updated.allDay, isTrue);

    await repository.deleteEvent(userId: 'user-1', eventId: created.id);
    expect(await database.select(database.calendarEvents).get(), isEmpty);
    outbox = await database.select(database.syncOutbox).get();
    expect(outbox.last.operation, 'delete');
  });

  test('calendar event rejects reversed time range', () {
    expect(
      () => repository.createEvent(
        userId: 'user-1',
        deviceId: 'device-1',
        title: 'Invalid',
        startAt: '2026-09-11T08:00:00.000Z',
        endAt: '2026-09-11T07:00:00.000Z',
      ),
      throwsArgumentError,
    );
  });
}
