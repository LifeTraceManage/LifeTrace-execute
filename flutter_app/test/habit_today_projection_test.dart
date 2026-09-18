import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/domain/habit/habit.dart';
import 'package:lifetrace_execute/features/habits/habit_providers.dart';

void main() {
  test('Today habit projection filters schedule and chooses latest log', () {
    final monday = DateTime(2026, 9, 14);
    final activities = [
      _activity('scheduled', targetDays: const [1]),
      _activity('other-day', targetDays: const [2]),
      _activity('archived', archived: true),
      _activity('future', startDate: '2026-09-15'),
    ];
    final logs = [
      _log(
        'old',
        'scheduled',
        updatedAt: '2026-09-14T01:00:00Z',
        status: HabitWireValues.logPartial,
      ),
      _log(
        'new',
        'scheduled',
        updatedAt: '2026-09-14T02:00:00Z',
        status: HabitWireValues.logCompleted,
      ),
    ];

    final entries = buildTodayHabitEntries(
      activities: activities,
      logs: logs,
      date: monday,
    );

    expect(entries, hasLength(1));
    expect(entries.single.activity.id, 'scheduled');
    expect(entries.single.log?.id, 'new');
    expect(entries.single.completed, isTrue);
  });
}

HabitActivity _activity(
  String id, {
  List<int> targetDays = const [],
  bool archived = false,
  String? startDate,
}) =>
    HabitActivity(
      id: id,
      userId: 'user-1',
      name: id,
      activityType: HabitWireValues.activityCompletion,
      unit: 'done',
      targetPeriod: 'daily',
      targetDays: targetDays,
      isArchived: archived,
      startDate: startDate,
      createdAt: '2026-09-01T00:00:00Z',
      updatedAt: '2026-09-01T00:00:00Z',
      localVersion: 1,
    );

HabitLog _log(
  String id,
  String activityId, {
  required String updatedAt,
  required String status,
}) =>
    HabitLog(
      id: id,
      userId: 'user-1',
      activityId: activityId,
      logDate: '2026-09-14',
      value: 1,
      status: status,
      createdAt: '2026-09-14T00:00:00Z',
      updatedAt: updatedAt,
      localVersion: 1,
    );
