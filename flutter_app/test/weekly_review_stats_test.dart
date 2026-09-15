import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/domain/focus/execution_focus_session.dart';
import 'package:lifetrace_execute/domain/focus/focus_timer_state.dart';
import 'package:lifetrace_execute/domain/task/execution_task.dart';
import 'package:lifetrace_execute/features/review/weekly_review_stats.dart';

void main() {
  test('week range is Monday through Sunday', () {
    final range = reviewWeekFor(DateTime(2026, 9, 9));
    expect(range.startKey, '2026-09-07');
    expect(range.endKey, '2026-09-13');
  });

  test('weekly stats deduplicate tasks and sum focus sessions', () {
    final tasks = [
      _task(
        'done',
        'Finished task',
        status: ExecutionTaskStatus.done,
        scheduledAt: '2026-09-08T09:00:00',
        dueAt: '2026-09-09T18:00:00',
        completedAt: '2026-09-10T10:00:00',
      ),
      _task(
        'open',
        'Open task',
        dueAt: '2026-09-12T18:00:00',
      ),
      _task(
        'outside',
        'Outside task',
        scheduledAt: '2026-09-14T08:00:00',
      ),
      _task(
        'next-urgent',
        'Next urgent',
        priority: ExecutionTaskPriority.urgent,
        dueAt: '2026-09-15T20:00:00',
      ),
    ];

    const sessions = [
      ExecutionFocusSession(
        id: 'focus-1',
        userId: 'user-1',
        mode: FocusMode.short,
        startedAt: '2026-09-09T09:00:00',
        endedAt: '2026-09-09T09:25:00',
        focusSeconds: 1500,
        completed: true,
        createdAt: '2026-09-09T09:25:00',
        updatedAt: '2026-09-09T09:25:00',
        localVersion: 1,
      ),
      ExecutionFocusSession(
        id: 'focus-2',
        userId: 'user-1',
        mode: FocusMode.long,
        startedAt: '2026-09-12T10:00:00',
        endedAt: '2026-09-12T10:30:00',
        focusSeconds: 1800,
        completed: false,
        createdAt: '2026-09-12T10:30:00',
        updatedAt: '2026-09-12T10:30:00',
        localVersion: 1,
      ),
      ExecutionFocusSession(
        id: 'focus-outside',
        userId: 'user-1',
        mode: FocusMode.short,
        startedAt: '2026-09-14T10:00:00',
        endedAt: '2026-09-14T10:25:00',
        focusSeconds: 1500,
        completed: true,
        createdAt: '2026-09-14T10:25:00',
        updatedAt: '2026-09-14T10:25:00',
        localVersion: 1,
      ),
    ];

    final result = calculateWeeklyReviewStats(
      tasks: tasks,
      focusSessions: sessions,
      weekStart: '2026-09-07',
    );

    expect(result.completed, 1);
    expect(result.total, 2);
    expect(result.completionScore, 0.5);
    expect(result.focusSeconds, 3300);
    expect(result.completedTitles, ['Finished task']);
    expect(result.nextWeekSuggestion, 'Next urgent');
    expect(
      weeklyCompletionSummarySuggestion(result),
      contains('Finished task'),
    );
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
      createdAt: '2026-09-01T00:00:00',
      updatedAt: '2026-09-10T00:00:00',
      localVersion: 1,
    );
