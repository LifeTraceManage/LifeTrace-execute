import '../../domain/focus/execution_focus_session.dart';

class FocusTodayStats {
  const FocusTodayStats({
    required this.focusSeconds,
    required this.completedRounds,
    required this.streakDays,
  });

  final int focusSeconds;
  final int completedRounds;
  final int streakDays;
}

FocusTodayStats calculateFocusTodayStats(
  Iterable<ExecutionFocusSession> sessions, {
  DateTime? now,
}) {
  final current = (now ?? DateTime.now()).toLocal();
  final today = DateTime(current.year, current.month, current.day);
  var seconds = 0;
  var completed = 0;
  final completedDays = <DateTime>{};

  for (final session in sessions) {
    final ended = DateTime.tryParse(session.endedAt)?.toLocal();
    if (ended == null) continue;
    final day = DateTime(ended.year, ended.month, ended.day);
    if (day == today) {
      seconds += session.focusSeconds;
      if (session.completed) completed++;
    }
    if (session.completed) completedDays.add(day);
  }

  var streak = 0;
  var cursor = today;
  while (completedDays.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }

  return FocusTodayStats(
    focusSeconds: seconds,
    completedRounds: completed,
    streakDays: streak,
  );
}
