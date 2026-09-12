import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/data/local/app_database.dart';
import 'package:lifetrace_execute/data/repository/important_date_repository.dart';
import 'package:lifetrace_execute/data/sync/important_date_conflict_resolver.dart';
import 'package:lifetrace_execute/domain/important_date/execution_important_date.dart';

void main() {
  late AppDatabase database;
  late DriftImportantDateRepository repository;
  late ImportantDateConflictResolver resolver;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftImportantDateRepository(database);
    resolver = ImportantDateConflictResolver(database);
  });

  tearDown(() async => database.close());

  test('keepServer replaces local important date and clears queue', () async {
    final local = await repository.createImportantDate(
      userId: 'user-1',
      deviceId: 'local-device',
      title: '本地生日',
      repeat: ImportantDateRepeat.yearly,
      kind: ImportantDateKind.birthday,
      calendar: ImportantDateCalendar.solar,
      solarDate: DateTime(2026, 9, 12),
    );
    await (database.update(database.syncOutbox)
          ..where((table) => table.entityId.equals(local.id)))
        .write(const SyncOutboxCompanion(blocked: Value(true)));

    await database.into(database.syncConflicts).insert(
          SyncConflictsCompanion.insert(
            id: 'important-conflict-server',
            userId: 'user-1',
            entityType: DriftImportantDateRepository.entityType,
            entityId: local.id,
            createdAt: '2026-09-12T00:00:00Z',
            serverPayloadJson: Value(
              jsonEncode(_payload(local.id, title: '云端生日')),
            ),
            serverVersion: const Value('9'),
            reason: const Value('changed remotely'),
          ),
        );

    await resolver.keepServer('important-conflict-server');

    final item = (await database.select(database.importantDates).get()).single;
    expect(item.title, '云端生日');
    expect(item.serverVersion, '9');
    expect(await database.select(database.syncOutbox).get(), isEmpty);
    expect(await database.select(database.syncConflicts).get(), isEmpty);
  });

  test('keepLocal rebases local fields onto latest server version', () async {
    final first = await repository.createImportantDate(
      userId: 'user-1',
      deviceId: 'local-device',
      title: '第一版',
      repeat: ImportantDateRepeat.yearly,
      kind: ImportantDateKind.anniversary,
      calendar: ImportantDateCalendar.solar,
      solarDate: DateTime(2026, 9, 12),
    );
    await repository.updateImportantDate(
      item: first,
      deviceId: 'local-device',
      title: '本地最新版',
      repeat: first.repeat,
      kind: first.kind,
      calendar: first.calendar,
      solarDate: DateTime(2026, 9, 12),
      enabled: true,
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
            id: 'important-conflict-local',
            userId: 'user-1',
            entityType: DriftImportantDateRepository.entityType,
            entityId: first.id,
            createdAt: '2026-09-12T00:00:00Z',
            changeId: Value(oldest.changeId),
            serverPayloadJson:
                Value(jsonEncode(_payload(first.id, title: '云端版本'))),
            serverVersion: const Value('15'),
            reason: const Value('changed remotely'),
          ),
        );

    await resolver.keepLocal(
      conflictId: 'important-conflict-local',
      deviceId: 'device-rebase',
    );

    final item = (await database.select(database.importantDates).get()).single;
    expect(item.title, '本地最新版');
    expect(item.serverVersion, '15');
    expect(item.modifiedByDevice, 'device-rebase');

    final outbox = await database.select(database.syncOutbox).get();
    expect(outbox, hasLength(1));
    expect(outbox.single.baseServerVersion, '15');
    expect(jsonDecode(outbox.single.payloadJson!)['title'], '本地最新版');
    expect(await database.select(database.syncConflicts).get(), isEmpty);
  });
}

Map<String, dynamic> _payload(String id, {required String title}) => {
      'id': id,
      'userId': 'user-1',
      'title': title,
      'date': '2026-09-12',
      'repeat': 'yearly',
      'kind': 'birthday',
      'calendar': 'solar',
      'lunarYear': null,
      'lunarMonth': null,
      'lunarDay': null,
      'lunarLeapMonth': false,
      'enabled': true,
    };
