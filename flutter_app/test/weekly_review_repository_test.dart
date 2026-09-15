import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/data/local/app_database.dart';
import 'package:lifetrace_execute/data/repository/weekly_review_repository.dart';

void main() {
  late AppDatabase database;
  late DriftWeeklyReviewRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftWeeklyReviewRepository(database);
  });

  tearDown(() async => database.close());

  test('saving same week updates one row and queues revisions', () async {
    final first = await repository.saveReview(
      userId: 'user-1',
      deviceId: 'device-1',
      weekStart: '2026-09-07',
      weekEnd: '2026-09-13',
      completionScore: 0.5,
      completedTaskCount: 2,
      totalTaskCount: 4,
      focusSeconds: 3600,
      bestThing: 'Started',
    );

    final second = await repository.saveReview(
      userId: 'user-1',
      deviceId: 'device-2',
      weekStart: '2026-09-07',
      weekEnd: '2026-09-13',
      completionScore: 0.75,
      completedTaskCount: 3,
      totalTaskCount: 4,
      focusSeconds: 5400,
      bestThing: 'Improved',
      nextWeekPriority: 'Ship',
    );

    expect(second.id, first.id);
    expect(second.localVersion, 2);
    final rows = await database.select(database.weeklyReviews).get();
    expect(rows, hasLength(1));
    expect(rows.single.focusSeconds, 5400);
    expect(rows.single.bestThing, 'Improved');

    final outbox = await database.select(database.syncOutbox).get();
    expect(outbox, hasLength(2));
    expect(
      outbox.every(
        (row) =>
            row.entityType == DriftWeeklyReviewRepository.entityType &&
            row.entityId == first.id &&
            row.operation == 'upsert',
      ),
      isTrue,
    );
  });

  test('weekly review validates week boundary and stats', () async {
    await expectLater(
      repository.saveReview(
        userId: 'user-1',
        deviceId: 'device-1',
        weekStart: '2026-09-07',
        weekEnd: '2026-09-12',
      ),
      throwsArgumentError,
    );

    await expectLater(
      repository.saveReview(
        userId: 'user-1',
        deviceId: 'device-1',
        weekStart: '2026-09-07',
        weekEnd: '2026-09-13',
        completedTaskCount: 5,
        totalTaskCount: 4,
      ),
      throwsArgumentError,
    );

    await expectLater(
      repository.saveReview(
        userId: 'user-1',
        deviceId: 'device-1',
        weekStart: '2026-09-07',
        weekEnd: '2026-09-13',
        focusSeconds: -1,
      ),
      throwsArgumentError,
    );
  });
}
