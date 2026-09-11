import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/domain/task/execution_task.dart';
import 'package:lifetrace_execute/features/review/review_stats.dart';

void main() {
  test('review stats snapshot today and suggests highest priority tomorrow task', () {
    final tasks = [
      _task(
        'done-today',
        'Done today',
        status: ExecutionTaskStatus.done,
        scheduledAt: '2026-09-11T09:00:00',
        completedAt: '2026-09-11T10:00:00',
      ),
      _task(
        'todo-today',
        'Still open',
        scheduledAt: '2026-09-11T14:00:00',
      ),
      _task(
        'tomorrow-normal',
        'Normal tomorrow',
        scheduledAt: '2026-09-12T08:00:00',
      ),
      _task(
        'tomorrow-urgent',
        'Urgent tomorrow',
        priority: ExecutionTaskPriority.urgent,
        dueAt: '2026-09-12T20:00:00',
      ),
    ];

    final stats = calculateReviewTaskStats(tasks, '2026-09-11');

    expect(stats.completed, 1);
    expect(stats.total, 2);
    expect(stats.completionScore, 0.5);
    expect(stats.tomorrowSuggestion, 'Urgent tomorrow');
  });
}

ExecutionTask _task(
  String id,
  String title, {
  ExecutionTaskStatus status = ExecutionTaskStatus.todo,
  ExecutionTaskPriority priority = ExecutionTaskPriority.normal,
  String? dueAt,
  String? scheduledAt,
  String? completedAt,
}) =>
    ExecutionTask(
      id: id,
      userId: 'user-1',
      title: title,
      status: status,
      priority: priority,
      dueAt: dueAt,
      scheduledAt: scheduledAt,
      completedAt: completedAt,
      createdAt: '2026-09-10T00:00:00.000Z',
      updatedAt: '2026-09-11T00:00:00.000Z',
      localVersion: 1,
    );
