import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/data/repository/daily_review_repository.dart';
import 'package:lifetrace_execute/domain/review/daily_review.dart';

void main() {
  test('daily review wire mapper matches Cloud review.daily contract', () {
    const review = DailyReview(
      id: 'review-1',
      userId: 'user-1',
      reviewDate: '2026-09-11',
      energy: 4,
      mood: 5,
      completionScore: 0.75,
      bestThing: 'Finished the important work',
      problem: 'Started too late',
      tomorrowPriority: 'Run experiment',
      note: 'Keep the morning free',
      completedTaskCount: 3,
      totalTaskCount: 4,
      createdAt: '2026-09-11T10:00:00.000Z',
      updatedAt: '2026-09-11T11:00:00.000Z',
      localVersion: 2,
      serverVersion: '7',
      modifiedByDevice: 'device-1',
    );

    final payload = DailyReviewWireMapper.toPayload(review);
    expect(payload['reviewDate'], '2026-09-11');
    expect(payload['completionScore'], 0.75);
    expect(payload['completedTaskCount'], 3);
    expect(payload['totalTaskCount'], 4);
    expect((payload['meta'] as Map)['id'], 'review-1');
    expect((payload['meta'] as Map)['serverVersion'], '7');

    final parsed = DailyReviewWireMapper.fromPayload(
      payload,
      serverVersion: '8',
    );
    expect(parsed.id, review.id);
    expect(parsed.reviewDate, review.reviewDate);
    expect(parsed.mood, 5);
    expect(parsed.energy, 4);
    expect(parsed.bestThing, review.bestThing);
    expect(parsed.serverVersion, '8');
  });
}
