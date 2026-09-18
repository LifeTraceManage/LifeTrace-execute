import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/data/repository/weekly_review_repository.dart';
import 'package:lifetrace_execute/domain/review/weekly_review.dart';

void main() {
  test('weekly review wire mapper matches Cloud typed contract', () {
    const review = WeeklyReview(
      id: 'weekly-1',
      userId: 'user-1',
      weekStart: '2026-09-07',
      weekEnd: '2026-09-13',
      completionScore: 0.75,
      completedTaskCount: 3,
      totalTaskCount: 4,
      focusSeconds: 5400,
      completionSummary: 'Finished three key tasks',
      bestThing: 'Protected focus time',
      problem: 'Too many context switches',
      improvement: 'Batch meetings',
      nextWeekPriority: 'Ship experiment',
      note: 'Keep mornings free',
      createdAt: '2026-09-13T10:00:00.000Z',
      updatedAt: '2026-09-13T11:00:00.000Z',
      localVersion: 2,
      serverVersion: '7',
      modifiedByDevice: 'device-1',
    );

    final payload = WeeklyReviewWireMapper.toPayload(review);
    expect(payload['weekStart'], '2026-09-07');
    expect(payload['weekEnd'], '2026-09-13');
    expect(payload['completionScore'], 0.75);
    expect(payload['completedTaskCount'], 3);
    expect(payload['totalTaskCount'], 4);
    expect(payload['focusSeconds'], 5400);
    expect(payload['improvement'], 'Batch meetings');
    expect((payload['meta'] as Map)['serverVersion'], '7');

    final parsed = WeeklyReviewWireMapper.fromPayload(
      payload,
      serverVersion: '8',
    );
    expect(parsed.id, review.id);
    expect(parsed.weekStart, review.weekStart);
    expect(parsed.weekEnd, review.weekEnd);
    expect(parsed.focusSeconds, 5400);
    expect(parsed.nextWeekPriority, 'Ship experiment');
    expect(parsed.serverVersion, '8');
  });
}
