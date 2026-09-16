import '../../domain/calendar/execution_calendar_event.dart';
import '../../domain/project/execution_project.dart';
import '../../domain/task/execution_task.dart';

enum TodayTimelineKind { task, calendarEvent }

class TodayTimelineEntry {
  const TodayTimelineEntry({
    required this.kind,
    required this.title,
    required this.start,
    required this.allDay,
    this.subtitle,
    this.end,
    this.task,
    this.event,
  });

  final TodayTimelineKind kind;
  final String title;
  final String? subtitle;
  final DateTime start;
  final DateTime? end;
  final bool allDay;
  final ExecutionTask? task;
  final ExecutionCalendarEvent? event;
}

class TodayPendingTask {
  const TodayPendingTask({
    required this.task,
    required this.overdue,
    required this.sortAt,
    this.projectName,
  });

  final ExecutionTask task;
  final String? projectName;
  final bool overdue;
  final DateTime? sortAt;
}

class TodaySnapshot {
  const TodaySnapshot({
    required this.now,
    required this.pendingTasks,
    required this.timeline,
    required this.todayTaskCount,
    required this.completedTaskCount,
    required this.calendarEventCount,
    required this.habitDueCount,
    required this.completedHabitCount,
    required this.completionRate,
    required this.overdueTaskCount,
  });

  final DateTime now;
  final List<TodayPendingTask> pendingTasks;
  final List<TodayTimelineEntry> timeline;
  final int todayTaskCount;
  final int completedTaskCount;
  final int calendarEventCount;
  final int habitDueCount;
  final int completedHabitCount;
  final double completionRate;
  final int overdueTaskCount;

  int get completedActionCount => completedTaskCount + completedHabitCount;
  int get totalActionCount => todayTaskCount + habitDueCount;
}

TodaySnapshot buildTodaySnapshot({
  required DateTime now,
  required Iterable<ExecutionTask> tasks,
  required Iterable<ExecutionProject> projects,
  required Iterable<ExecutionCalendarEvent> events,
  required int habitDueCount,
  required int completedHabitCount,
}) {
  final localNow = now.toLocal();
  final dayStart = DateTime(localNow.year, localNow.month, localNow.day);
  final dayEnd = dayStart.add(const Duration(days: 1));
  final projectNames = <String, String>{
    for (final project in projects) project.id: project.title,
  };

  final relevantTasks = <ExecutionTask>[];
  final pending = <TodayPendingTask>[];
  final timeline = <TodayTimelineEntry>[];

  for (final task in tasks) {
    final scheduled = _parseLocal(task.scheduledAt);
    final due = _parseLocal(task.dueAt);
    final completed = _parseLocal(task.completedAt);
    final scheduledToday = _inDay(scheduled, dayStart, dayEnd);
    final dueToday = _inDay(due, dayStart, dayEnd);
    final completedToday = _inDay(completed, dayStart, dayEnd);
    final overdue = !task.isDone && due != null && due.isBefore(dayStart);
    final relevant = scheduledToday ||
        dueToday ||
        completedToday ||
        overdue ||
        (!task.isDone && task.status == ExecutionTaskStatus.inProgress);

    if (relevant) {
      relevantTasks.add(task);
      if (!task.isDone) {
        pending.add(
          TodayPendingTask(
            task: task,
            projectName:
                task.projectId == null ? null : projectNames[task.projectId],
            overdue: overdue,
            sortAt: scheduled ?? due,
          ),
        );
      }
    }

    if (scheduledToday && scheduled != null) {
      timeline.add(
        TodayTimelineEntry(
          kind: TodayTimelineKind.task,
          title: task.title,
          subtitle:
              task.projectId == null ? null : projectNames[task.projectId],
          start: scheduled,
          allDay: false,
          task: task,
        ),
      );
    }
  }

  final todayEvents = <ExecutionCalendarEvent>[];
  for (final event in events) {
    final start = _parseLocal(event.startAt);
    if (start == null) continue;
    final end = _parseLocal(event.endAt);
    if (!_eventOverlapsDay(
      start: start,
      end: end,
      dayStart: dayStart,
      dayEnd: dayEnd,
    )) {
      continue;
    }
    todayEvents.add(event);
    timeline.add(
      TodayTimelineEntry(
        kind: TodayTimelineKind.calendarEvent,
        title: event.title,
        subtitle: event.location ?? event.description,
        start: start,
        end: end,
        allDay: event.allDay,
        event: event,
      ),
    );
  }

  pending.sort(_comparePendingTasks);
  timeline.sort(_compareTimeline);

  final completedTasks = relevantTasks.where((task) => task.isDone).length;
  final totalActions = relevantTasks.length + habitDueCount;
  final completedActions = completedTasks + completedHabitCount;
  final completionRate = totalActions == 0
      ? 0.0
      : (completedActions / totalActions).clamp(0.0, 1.0).toDouble();

  return TodaySnapshot(
    now: localNow,
    pendingTasks: List.unmodifiable(pending),
    timeline: List.unmodifiable(timeline),
    todayTaskCount: relevantTasks.length,
    completedTaskCount: completedTasks,
    calendarEventCount: todayEvents.length,
    habitDueCount: habitDueCount,
    completedHabitCount: completedHabitCount,
    completionRate: completionRate,
    overdueTaskCount: pending.where((item) => item.overdue).length,
  );
}

bool isSameLocalDay(DateTime value, DateTime day) {
  final localValue = value.toLocal();
  final localDay = day.toLocal();
  return localValue.year == localDay.year &&
      localValue.month == localDay.month &&
      localValue.day == localDay.day;
}

DateTime startOfLocalWeek(DateTime value) {
  final local = value.toLocal();
  final day = DateTime(local.year, local.month, local.day);
  return day.subtract(Duration(days: local.weekday - DateTime.monday));
}

String todayGreeting(DateTime value) {
  final hour = value.toLocal().hour;
  if (hour < 5) return '夜深了';
  if (hour < 11) return '早上好';
  if (hour < 13) return '中午好';
  if (hour < 18) return '下午好';
  return '晚上好';
}

DateTime? _parseLocal(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  return DateTime.tryParse(raw)?.toLocal();
}

bool _inDay(DateTime? value, DateTime start, DateTime end) =>
    value != null && !value.isBefore(start) && value.isBefore(end);

bool _eventOverlapsDay({
  required DateTime start,
  required DateTime? end,
  required DateTime dayStart,
  required DateTime dayEnd,
}) {
  if (end == null) return _inDay(start, dayStart, dayEnd);
  if (!end.isAfter(start)) return _inDay(start, dayStart, dayEnd);
  return start.isBefore(dayEnd) && end.isAfter(dayStart);
}

int _comparePendingTasks(TodayPendingTask a, TodayPendingTask b) {
  if (a.overdue != b.overdue) return a.overdue ? -1 : 1;
  final priority = _priorityRank(b.task.priority)
      .compareTo(_priorityRank(a.task.priority));
  if (priority != 0) return priority;
  final aTime = a.sortAt;
  final bTime = b.sortAt;
  if (aTime != null && bTime != null) return aTime.compareTo(bTime);
  if (aTime != null) return -1;
  if (bTime != null) return 1;
  return b.task.updatedAt.compareTo(a.task.updatedAt);
}

int _priorityRank(ExecutionTaskPriority priority) => switch (priority) {
      ExecutionTaskPriority.low => 0,
      ExecutionTaskPriority.normal => 1,
      ExecutionTaskPriority.high => 2,
      ExecutionTaskPriority.urgent => 3,
    };

int _compareTimeline(TodayTimelineEntry a, TodayTimelineEntry b) {
  if (a.allDay != b.allDay) return a.allDay ? -1 : 1;
  final time = a.start.compareTo(b.start);
  if (time != 0) return time;
  return a.title.compareTo(b.title);
}
