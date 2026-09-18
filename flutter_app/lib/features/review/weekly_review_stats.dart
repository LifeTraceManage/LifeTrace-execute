import '../../domain/focus/execution_focus_session.dart';
import '../../domain/task/execution_task.dart';

class ReviewWeekRange {
  const ReviewWeekRange({
    required this.start,
    required this.end,
  });

  final DateTime start;
  final DateTime end;

  String get startKey => reviewWeekDateKey(start);
  String get endKey => reviewWeekDateKey(end);
}

class WeeklyReviewStats {
  const WeeklyReviewStats({
    required this.completed,
    required this.total,
    required this.completionScore,
    required this.focusSeconds,
    required this.completedTitles,
    this.nextWeekSuggestion,
  });

  final int completed;
  final int total;
  final double? completionScore;
  final int focusSeconds;
  final List<String> completedTitles;
  final String? nextWeekSuggestion;
}

ReviewWeekRange reviewWeekFor(DateTime value) {
  final local = value.toLocal();
  final date = DateTime(local.year, local.month, local.day);
  final start = date.subtract(Duration(days: date.weekday - DateTime.monday));
  return ReviewWeekRange(
    start: start,
    end: start.add(const Duration(days: 6)),
  );
}

ReviewWeekRange reviewWeekFromStartKey(String weekStart) {
  final start = DateTime.tryParse('${weekStart}T00:00:00');
  if (start == null || reviewWeekDateKey(start) != weekStart) {
    throw ArgumentError.value(weekStart, 'weekStart', '必须是有效 YYYY-MM-DD');
  }
  return ReviewWeekRange(
    start: start,
    end: start.add(const Duration(days: 6)),
  );
}

String reviewWeekDateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

WeeklyReviewStats calculateWeeklyReviewStats({
  required List<ExecutionTask> tasks,
  required List<ExecutionFocusSession> focusSessions,
  required String weekStart,
}) {
  final range = reviewWeekFromStartKey(weekStart);
  final relevant = tasks.where((task) {
    return _instantInRange(task.scheduledAt, range) ||
        _instantInRange(task.dueAt, range) ||
        _instantInRange(task.completedAt, range);
  }).toList(growable: false);

  final completed = relevant.where((task) => task.isDone).length;
  final total = relevant.length;
  final focusSeconds = focusSessions
      .where((session) => _instantInRange(session.endedAt, range))
      .fold(0, (sum, session) => sum + session.focusSeconds);

  final completedTitles = tasks
      .where(
        (task) =>
            task.isDone && _instantInRange(task.completedAt, range),
      )
      .map((task) => task.title)
      .take(6)
      .toList(growable: false);

  final nextWeek = ReviewWeekRange(
    start: range.end.add(const Duration(days: 1)),
    end: range.end.add(const Duration(days: 7)),
  );
  final nextCandidates = tasks
      .where(
        (task) =>
            !task.isDone &&
            (_instantInRange(task.scheduledAt, nextWeek) ||
                _instantInRange(task.dueAt, nextWeek)),
      )
      .toList();
  nextCandidates.sort((a, b) {
    final priority =
        _priorityWeight(b.priority).compareTo(_priorityWeight(a.priority));
    if (priority != 0) return priority;
    return _sortTime(a.scheduledAt ?? a.dueAt)
        .compareTo(_sortTime(b.scheduledAt ?? b.dueAt));
  });

  return WeeklyReviewStats(
    completed: completed,
    total: total,
    completionScore: total == 0 ? null : completed / total,
    focusSeconds: focusSeconds,
    completedTitles: completedTitles,
    nextWeekSuggestion:
        nextCandidates.isEmpty ? null : nextCandidates.first.title,
  );
}

String weeklyCompletionSummarySuggestion(WeeklyReviewStats stats) {
  if (stats.completedTitles.isEmpty) {
    return stats.completed == 0
        ? '本周暂无完成任务'
        : '本周完成 ${stats.completed} 项任务';
  }
  return '完成 ${stats.completed} 项：${stats.completedTitles.join('、')}';
}

bool _instantInRange(String? raw, ReviewWeekRange range) {
  final value = raw == null ? null : DateTime.tryParse(raw)?.toLocal();
  if (value == null) return false;
  final date = DateTime(value.year, value.month, value.day);
  return !date.isBefore(range.start) && !date.isAfter(range.end);
}

DateTime _sortTime(String? raw) =>
    DateTime.tryParse(raw ?? '')?.toLocal() ??
    DateTime.fromMillisecondsSinceEpoch(8640000000000000);

int _priorityWeight(ExecutionTaskPriority value) => switch (value) {
      ExecutionTaskPriority.urgent => 4,
      ExecutionTaskPriority.high => 3,
      ExecutionTaskPriority.normal => 2,
      ExecutionTaskPriority.low => 1,
    };
