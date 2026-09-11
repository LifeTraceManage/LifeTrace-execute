import '../../domain/task/execution_task.dart';

class ReviewTaskStats {
  const ReviewTaskStats({
    required this.completed,
    required this.total,
    required this.completionScore,
    this.tomorrowSuggestion,
  });

  final int completed;
  final int total;
  final double? completionScore;
  final String? tomorrowSuggestion;
}

ReviewTaskStats calculateReviewTaskStats(
  List<ExecutionTask> tasks,
  String reviewDate,
) {
  final date = DateTime.tryParse('${reviewDate}T00:00:00');
  if (date == null) {
    throw ArgumentError.value(reviewDate, 'reviewDate', '必须是 YYYY-MM-DD');
  }

  final todayTasks = tasks.where((task) {
    return _sameLocalDate(task.scheduledAt, reviewDate) ||
        _sameLocalDate(task.dueAt, reviewDate) ||
        _sameLocalDate(task.completedAt, reviewDate);
  }).toList(growable: false);

  final completed = todayTasks.where((task) => task.isDone).length;
  final total = todayTasks.length;
  final tomorrow = date.add(const Duration(days: 1));
  final tomorrowDate = _dateKey(tomorrow);
  final candidates = tasks
      .where(
        (task) =>
            !task.isDone &&
            (_sameLocalDate(task.scheduledAt, tomorrowDate) ||
                _sameLocalDate(task.dueAt, tomorrowDate)),
      )
      .toList();
  candidates.sort((a, b) {
    final priority =
        _priorityWeight(b.priority).compareTo(_priorityWeight(a.priority));
    if (priority != 0) return priority;
    final aTime = _sortTime(a.scheduledAt ?? a.dueAt);
    final bTime = _sortTime(b.scheduledAt ?? b.dueAt);
    return aTime.compareTo(bTime);
  });

  return ReviewTaskStats(
    completed: completed,
    total: total,
    completionScore: total == 0 ? null : completed / total,
    tomorrowSuggestion: candidates.isEmpty ? null : candidates.first.title,
  );
}

bool _sameLocalDate(String? raw, String date) {
  final parsed = raw == null ? null : DateTime.tryParse(raw);
  if (parsed == null) return false;
  return _dateKey(parsed.toLocal()) == date;
}

String _dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

DateTime _sortTime(String? raw) =>
    DateTime.tryParse(raw ?? '')?.toLocal() ??
    DateTime.fromMillisecondsSinceEpoch(8640000000000000);

int _priorityWeight(ExecutionTaskPriority value) => switch (value) {
      ExecutionTaskPriority.urgent => 4,
      ExecutionTaskPriority.high => 3,
      ExecutionTaskPriority.normal => 2,
      ExecutionTaskPriority.low => 1,
    };
