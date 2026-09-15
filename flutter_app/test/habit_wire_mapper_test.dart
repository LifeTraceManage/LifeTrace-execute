import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/data/repository/habit_repository.dart';
import 'package:lifetrace_execute/domain/habit/habit.dart';

void main() {
  test('habit activity wire mapper matches Cloud typed contract', () {
    const activity = HabitActivity(
      id: 'habit-1',
      userId: 'user-1',
      name: 'Deep work',
      activityType: HabitWireValues.activityDuration,
      unit: 'minutes',
      minimumTarget: 30,
      normalTarget: 60,
      targetPeriod: 'daily',
      targetDays: [1, 2, 3, 4, 5],
      scheduleType: HabitWireValues.scheduleCustom,
      startDate: '2026-09-15',
      checkinMethod: HabitWireValues.checkinManual,
      description: 'Protect one hour',
      isArchived: false,
      createdAt: '2026-09-15T01:00:00.000Z',
      updatedAt: '2026-09-15T02:00:00.000Z',
      localVersion: 2,
      serverVersion: '7',
      modifiedByDevice: 'device-1',
    );

    final payload = HabitActivityWireMapper.toPayload(activity);
    expect(payload['activityType'], 'duration');
    expect(payload['normalTarget'], 60);
    expect(payload['targetDays'], [1, 2, 3, 4, 5]);
    expect((payload['meta'] as Map)['serverVersion'], '7');

    final parsed = HabitActivityWireMapper.fromPayload(
      payload,
      serverVersion: '8',
    );
    expect(parsed.id, activity.id);
    expect(parsed.name, activity.name);
    expect(parsed.targetDays, activity.targetDays);
    expect(parsed.serverVersion, '8');
  });

  test('habit log wire mapper preserves date status value and metadata', () {
    const log = HabitLog(
      id: 'log-1',
      userId: 'user-1',
      activityId: 'habit-1',
      logDate: '2026-09-15',
      value: 45,
      status: HabitWireValues.logPartial,
      note: 'Interrupted once',
      metadata: {'source': 'execute'},
      createdAt: '2026-09-15T02:00:00.000Z',
      updatedAt: '2026-09-15T02:30:00.000Z',
      localVersion: 1,
      serverVersion: '3',
      modifiedByDevice: 'device-1',
    );

    final payload = HabitLogWireMapper.toPayload(log);
    expect(payload['activityId'], 'habit-1');
    expect(payload['logDate'], '2026-09-15');
    expect(payload['status'], 'partial');
    expect(payload['metadata'], {'source': 'execute'});

    final parsed = HabitLogWireMapper.fromPayload(
      payload,
      serverVersion: '4',
    );
    expect(parsed.value, 45);
    expect(parsed.metadata?['source'], 'execute');
    expect(parsed.serverVersion, '4');
  });
}
