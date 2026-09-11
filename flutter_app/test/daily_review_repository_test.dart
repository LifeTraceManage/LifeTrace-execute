import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/data/local/app_database.dart';
import 'package:lifetrace_execute/data/repository/daily_review_repository.dart';

void main() {
  late AppDatabase database;
  late DriftDailyReviewRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftDailyReviewRepository(database);
  });

  tearDown(() async => database.close());

  test('saving the same date updates one local review and queues revisions', () async {
    final first = await repository.saveReview(
      userId: 'user-1',
      deviceId: 'device-1',
      reviewDate: '2026-09-11',
      mood: 4,
      energy: 3,
      completionScore: 0.5,
      completedTaskCount: 1,
      totalTaskCount: 2,
      bestThing: 'Started',
    );

    final second = await repository.saveReview(
      userId: 'user-1',
      deviceId: 'device-1',
      reviewDate: '2026-09-11',
      mood: 5,
      energy: 4,
      completionScore: 1,
      completedTaskCount: 2,
      totalTaskCount: 2,
      bestThing: 'Finished',
    );

    expect(second.id, first.id);
    expect(second.localVersion, 2);
    final rows = await database.select(database.dailyReviews).get();
    expect(rows, hasLength(1));
    expect(rows.single.mood, 5);
    expect(rows.single.bestThing, 'Finished');

    final outbox = await database.select(database.syncOutbox).get();
    expect(outbox, hasLength(2));
    expect(
      outbox.every(
        (row) =>
            row.entityType == DriftDailyReviewRepository.entityType &&
            row.entityId == first.id &&
            row.operation == 'upsert',
      ),
      isTrue,
    );
  });

  test('daily review validates scales and task counts', () async {
    await expectLater(
      repository.saveReview(
        userId: 'user-1',
        deviceId: 'device-1',
        reviewDate: '2026-09-11',
        mood: 6,
      ),
      throwsArgumentError,
    );

    await expectLater(
      repository.saveReview(
        userId: 'user-1',
        deviceId: 'device-1',
        reviewDate: '2026-09-11',
        completedTaskCount: 3,
        totalTaskCount: 2,
      ),
      throwsArgumentError,
    );
  });
}
