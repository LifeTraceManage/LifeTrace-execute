import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/domain/calendar/execution_calendar_event.dart';
import 'package:lifetrace_execute/domain/project/execution_project.dart';
import 'package:lifetrace_execute/domain/task/execution_task.dart';
import 'package:lifetrace_execute/features/today/today_aggregation.dart';

void main() {
  const created = '2026-09-01T00:00:00.000';

  ExecutionTask task(
    String id, {
    ExecutionTaskStatus status = ExecutionTaskStatus.todo,
    ExecutionTaskPriority priority = ExecutionTaskPriority.normal,
    String? projectId,
    DateTime? scheduledAt,
    DateTime? dueAt,
    DateTime? completedAt,
  }) =>
      ExecutionTask(
        id: id,
        userId: 'user-1',
        title: id,
        status: status,
        priority: priority,
        projectId: projectId,
        scheduledAt: scheduledAt?.toIso8601String(),
        dueAt: dueAt?.toIso8601String(),
        completedAt: completedAt?.toIso8601String(),
        createdAt: created,
        updatedAt: created,
        localVersion: 1,
      );

  ExecutionProject project(String id, String title) => ExecutionProject(
        id: id,
        userId: 'user-1',
        title: title,
        createdAt: created,
        updatedAt: created,
        localVersion: 1,
      );

  ExecutionCalendarEvent event(
    String id,
    DateTime start, {
    DateTime? end,
    bool allDay = false,
  }) =>
      ExecutionCalendarEvent(
        id: id,
        userId: 'user-1',
        title: id,
        startAt: start.toIso8601String(),
        endAt: end?.toIso8601String(),
        allDay: allDay,
        createdAt: created,
        updatedAt: created,
        localVersion: 1,
      );

  test('aggregates relevant tasks, overdue work and habit completion', () {
    final now = DateTime(2026, 9, 16, 10);
    final snapshot = buildTodaySnapshot(
      now: now,
      projects: [project('p1', 'Research')],
      tasks: [
        task(
          'scheduled',
          projectId: 'p1',
          scheduledAt: DateTime(2026, 9, 16, 9),
        ),
        task(
          'overdue',
          priority: ExecutionTaskPriority.urgent,
          dueAt: DateTime(2026, 9, 16, 9),
        ),
        task(
          'done-today',
          status: ExecutionTaskStatus.done,
          completedAt: DateTime(2026, 9, 16, 8),
        ),
        task(
          'future',
          dueAt: DateTime(2026, 9, 17, 9),
        ),
      ],
      events: const [],
      habitDueCount: 2,
      completedHabitCount: 1,
    );

    expect(snapshot.todayTaskCount, 3);
    expect(snapshot.completedTaskCount, 1);
    expect(snapshot.pendingTasks, hasLength(2));
    expect(snapshot.pendingTasks.first.task.id, 'overdue');
    expect(snapshot.overdueTaskCount, 1);
    expect(snapshot.timeline.single.task?.id, 'scheduled');
    expect(snapshot.timeline.single.subtitle, 'Research');
    expect(snapshot.totalActionCount, 5);
    expect(snapshot.completedActionCount, 2);
    expect(snapshot.completionRate, closeTo(.4, .0001));
  });

  test('calendar events that overlap today are included and sorted', () {
    final now = DateTime(2026, 9, 16, 12);
    final snapshot = buildTodaySnapshot(
      now: now,
      tasks: [
        task('task-10', scheduledAt: DateTime(2026, 9, 16, 10)),
      ],
      projects: const [],
      events: [
        event(
          'spanning',
          DateTime(2026, 9, 15, 23),
          end: DateTime(2026, 9, 16, 1),
        ),
        event(
          'all-day',
          DateTime(2026, 9, 16),
          end: DateTime(2026, 9, 17),
          allDay: true,
        ),
        event(
          'tomorrow',
          DateTime(2026, 9, 17, 9),
        ),
      ],
      habitDueCount: 0,
      completedHabitCount: 0,
    );

    expect(snapshot.calendarEventCount, 2);
    expect(snapshot.timeline, hasLength(3));
    expect(snapshot.timeline.first.event?.id, 'all-day');
    expect(snapshot.timeline[1].event?.id, 'spanning');
    expect(snapshot.timeline[2].task?.id, 'task-10');
  });

  test('in-progress undated task remains visible while unrelated task does not', () {
    final snapshot = buildTodaySnapshot(
      now: DateTime(2026, 9, 16, 15),
      tasks: [
        task('working', status: ExecutionTaskStatus.inProgress),
        task('backlog'),
      ],
      projects: const [],
      events: const [],
      habitDueCount: 0,
      completedHabitCount: 0,
    );

    expect(snapshot.todayTaskCount, 1);
    expect(snapshot.pendingTasks.single.task.id, 'working');
  });

  test('week and greeting helpers follow local date and hour', () {
    final value = DateTime(2026, 9, 16, 9);
    final monday = startOfLocalWeek(value);

    expect(monday.weekday, DateTime.monday);
    expect(monday.day, 14);
    expect(todayGreeting(value), '早上好');
    expect(todayGreeting(DateTime(2026, 9, 16, 19)), '晚上好');
  });
}
