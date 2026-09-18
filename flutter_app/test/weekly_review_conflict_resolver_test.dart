import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/data/local/app_database.dart';
import 'package:lifetrace_execute/data/repository/weekly_review_repository.dart';
import 'package:lifetrace_execute/data/sync/weekly_review_conflict_resolver.dart';

void main() {
  late AppDatabase database;
  late DriftWeeklyReviewRepository repository;
  late WeeklyReviewConflictResolver resolver;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftWeeklyReviewRepository(database);
    resolver = WeeklyReviewConflictResolver(database);
  });

  tearDown(() async => database.close());

  test('keepServer replaces local weekly review and clears queue', () async {
    final local = await repository.saveReview(
      userId: 'user-1',
      deviceId: 'device-1',
      weekStart: '2026-09-07',
      weekEnd: '2026-09-13',
      bestThing: 'Local',
    );
    await (database.update(database.syncOutbox)
          ..where((table) => table.entityId.equals(local.id)))
        .write(const SyncOutboxCompanion(blocked: Value(true)));

    await database.into(database.syncConflicts).insert(
          SyncConflictsCompanion.insert(
            id: 'weekly-server',
            userId: 'user-1',
            entityType: DriftWeeklyReviewRepository.entityType,
            entityId: local.id,
            createdAt: '2026-09-13T00:00:00Z',
            serverPayloadJson: Value(
              jsonEncode(_payload(local.id, bestThing: 'Cloud')),
            ),
            serverVersion: const Value('9'),
            reason: const Value('changed remotely'),
          ),
        );

    await resolver.keepServer('weekly-server');

    final row = (await database.select(database.weeklyReviews).get()).single;
    expect(row.bestThing, 'Cloud');
    expect(row.serverVersion, '9');
    expect(await database.select(database.syncOutbox).get(), isEmpty);
    expect(await database.select(database.syncConflicts).get(), isEmpty);
  });

  test('keepLocal rebases latest local weekly review', () async {
    final first = await repository.saveReview(
      userId: 'user-1',
      deviceId: 'device-1',
      weekStart: '2026-09-07',
      weekEnd: '2026-09-13',
      bestThing: 'First',
    );
    await repository.saveReview(
      userId: 'user-1',
      deviceId: 'device-1',
      weekStart: '2026-09-07',
      weekEnd: '2026-09-13',
      bestThing: 'Latest local',
      focusSeconds: 3600,
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
            id: 'weekly-local',
            userId: 'user-1',
            entityType: DriftWeeklyReviewRepository.entityType,
            entityId: first.id,
            createdAt: '2026-09-13T00:00:00Z',
            changeId: Value(oldest.changeId),
            serverPayloadJson:
                Value(jsonEncode(_payload(first.id, bestThing: 'Cloud'))),
            serverVersion: const Value('15'),
            reason: const Value('changed remotely'),
          ),
        );

    await resolver.keepLocal(
      conflictId: 'weekly-local',
      deviceId: 'device-rebase',
    );

    final row = (await database.select(database.weeklyReviews).get()).single;
    expect(row.bestThing, 'Latest local');
    expect(row.focusSeconds, 3600);
    expect(row.serverVersion, '15');
    expect(row.modifiedByDevice, 'device-rebase');

    final outbox = await database.select(database.syncOutbox).get();
    expect(outbox, hasLength(1));
    expect(outbox.single.baseServerVersion, '15');
    expect(jsonDecode(outbox.single.payloadJson!)['bestThing'], 'Latest local');
    expect(await database.select(database.syncConflicts).get(), isEmpty);
  });
}

Map<String, dynamic> _payload(String id, {required String bestThing}) => {
      'meta': {
        'id': id,
        'userId': 'user-1',
        'createdAt': '2026-09-07T00:00:00Z',
        'updatedAt': '2026-09-13T00:00:00Z',
        'deletedAt': null,
        'localVersion': 1,
        'serverVersion': null,
        'modifiedByDevice': 'cloud-device',
      },
      'weekStart': '2026-09-07',
      'weekEnd': '2026-09-13',
      'completionScore': 0.5,
      'completedTaskCount': 2,
      'totalTaskCount': 4,
      'focusSeconds': 1800,
      'completionSummary': 'Cloud summary',
      'bestThing': bestThing,
      'problem': null,
      'improvement': null,
      'nextWeekPriority': null,
      'note': null,
    };
