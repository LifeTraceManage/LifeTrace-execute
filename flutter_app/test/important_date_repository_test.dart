import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/data/local/app_database.dart';
import 'package:lifetrace_execute/data/repository/important_date_repository.dart';
import 'package:lifetrace_execute/domain/important_date/execution_important_date.dart';

void main() {
  late AppDatabase database;
  late DriftImportantDateRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftImportantDateRepository(database);
  });

  tearDown(() async => database.close());

  test('lunar create stores raw source and queues exact Cloud payload', () async {
    final item = await repository.createImportantDate(
      userId: 'user-1',
      deviceId: 'device-1',
      title: '闰二月纪念日',
      repeat: ImportantDateRepeat.once,
      kind: ImportantDateKind.anniversary,
      calendar: ImportantDateCalendar.lunar,
      lunarYear: 2023,
      lunarMonth: 2,
      lunarDay: 1,
      lunarLeapMonth: true,
    );

    expect(item.date, '2023-03-22');
    expect(item.lunarYear, 2023);
    expect(item.lunarLeapMonth, isTrue);

    final rows = await database.select(database.importantDates).get();
    expect(rows, hasLength(1));
    expect(rows.single.date, '2023-03-22');

    final outbox = await database.select(database.syncOutbox).get();
    expect(outbox, hasLength(1));
    expect(outbox.single.entityType, DriftImportantDateRepository.entityType);
    final payload = jsonDecode(outbox.single.payloadJson!);
    expect(payload['calendar'], 'lunar');
    expect(payload['lunarYear'], 2023);
    expect(payload['lunarLeapMonth'], isTrue);
  });

  test('solar update clears lunar source fields and preserves server version',
      () async {
    final lunar = await repository.createImportantDate(
      userId: 'user-1',
      deviceId: 'device-1',
      title: '生日',
      repeat: ImportantDateRepeat.yearly,
      kind: ImportantDateKind.birthday,
      calendar: ImportantDateCalendar.lunar,
      lunarYear: 2024,
      lunarMonth: 1,
      lunarDay: 1,
    );

    await (database.update(database.importantDates)
          ..where((table) => table.id.equals(lunar.id)))
        .write(const ImportantDatesCompanion(serverVersion: Value('5')));
    final current = ImportantDateDatabaseMapper.fromRow(
      (await database.select(database.importantDates).get()).single,
    );

    final solar = await repository.updateImportantDate(
      item: current,
      deviceId: 'device-2',
      title: '生日',
      repeat: ImportantDateRepeat.yearly,
      kind: ImportantDateKind.birthday,
      calendar: ImportantDateCalendar.solar,
      solarDate: DateTime(2024, 2, 10),
      enabled: true,
    );

    expect(solar.serverVersion, '5');
    expect(solar.lunarYear, isNull);
    expect(solar.lunarMonth, isNull);
    expect(solar.lunarDay, isNull);
    expect(solar.lunarLeapMonth, isFalse);
    expect(solar.localVersion, 2);
  });

  test('invalid leap lunar month is rejected before local write', () async {
    await expectLater(
      repository.createImportantDate(
        userId: 'user-1',
        deviceId: 'device-1',
        title: '不存在的闰月',
        repeat: ImportantDateRepeat.once,
        kind: ImportantDateKind.other,
        calendar: ImportantDateCalendar.lunar,
        lunarYear: 2024,
        lunarMonth: 2,
        lunarDay: 1,
        lunarLeapMonth: true,
      ),
      throwsArgumentError,
    );
    expect(await database.select(database.importantDates).get(), isEmpty);
    expect(await database.select(database.syncOutbox).get(), isEmpty);
  });
}
