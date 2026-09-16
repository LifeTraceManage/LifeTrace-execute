import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/data/repository/goal_repository.dart';
import 'package:lifetrace_execute/domain/goal/execution_goal.dart';

void main() {
  test('goal wire mapper matches Cloud typed contract', () {
    const goal = ExecutionGoal(
      id: 'goal-1',
      userId: 'user-1',
      name: 'Finish thesis',
      description: 'Experiments and writing',
      status: ExecutionGoalStatus.active,
      targetAt: '2026-12-31T23:59:59.000Z',
      color: '#49715d',
      icon: 'target',
      sortOrder: 2,
      createdAt: '2026-09-16T01:00:00.000Z',
      updatedAt: '2026-09-16T02:00:00.000Z',
      localVersion: 3,
      serverVersion: '7',
      modifiedByDevice: 'device-1',
    );

    final payload = GoalWireMapper.toPayload(goal);
    expect(payload['name'], 'Finish thesis');
    expect(payload['status'], 'active');
    expect(payload['sortOrder'], 2);
    expect((payload['meta'] as Map)['serverVersion'], '7');

    final parsed = GoalWireMapper.fromPayload(
      payload,
      serverVersion: '8',
    );
    expect(parsed.id, goal.id);
    expect(parsed.name, goal.name);
    expect(parsed.targetAt, goal.targetAt);
    expect(parsed.serverVersion, '8');
  });

  test('goal wire mapper rejects unknown status', () {
    final payload = <String, dynamic>{
      'meta': {
        'id': 'goal-1',
        'userId': 'user-1',
        'createdAt': '2026-09-16T01:00:00.000Z',
        'updatedAt': '2026-09-16T01:00:00.000Z',
        'localVersion': 1,
      },
      'name': 'Goal',
      'status': 'doing',
      'sortOrder': 0,
    };

    expect(
      () => GoalWireMapper.fromPayload(payload, serverVersion: '1'),
      throwsFormatException,
    );
  });
}
