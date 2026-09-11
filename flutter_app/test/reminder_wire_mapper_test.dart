import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/data/repository/reminder_repository.dart';
import 'package:lifetrace_execute/domain/reminder/execution_reminder.dart';

void main() {
  test('reminder wire mapper matches typed Cloud execution.reminder contract', () {
    const reminder = ExecutionReminder(
      id: 'reminder-1',
      userId: 'user-1',
      subjectType: ReminderSubjectTypes.task,
      subjectId: 'task-1',
      triggerAt: '2026-09-12T01:30:00.000Z',
      status: ExecutionReminderStatus.scheduled,
      fireKey: 'task-1@2026-09-12T01:30:00.000Z',
      title: 'Finish report',
      body: 'LifeTrace Execute reminder',
      createdAt: '2026-09-11T12:00:00.000Z',
      updatedAt: '2026-09-11T12:05:00.000Z',
      localVersion: 2,
      serverVersion: '7',
      modifiedByDevice: 'device-1',
    );

    final payload = ReminderWireMapper.toPayload(reminder);
    expect(payload['subjectType'], 'task');
    expect(payload['subjectId'], 'task-1');
    expect(payload['triggerAt'], '2026-09-12T01:30:00.000Z');
    expect(payload['status'], 'scheduled');
    expect(payload['fireKey'], 'task-1@2026-09-12T01:30:00.000Z');
    expect((payload['meta'] as Map)['serverVersion'], '7');

    final parsed = ReminderWireMapper.fromPayload(
      payload,
      serverVersion: '8',
    );
    expect(parsed.id, 'reminder-1');
    expect(parsed.subjectType, ReminderSubjectTypes.task);
    expect(parsed.subjectId, 'task-1');
    expect(parsed.status, ExecutionReminderStatus.scheduled);
    expect(parsed.serverVersion, '8');
    expect(parsed.title, 'Finish report');
  });
}
