import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../calendar/calendar_providers.dart';
import '../habits/habit_providers.dart';
import '../projects/project_providers.dart';
import '../tasks/task_providers.dart';
import 'today_aggregation.dart';

final todayClockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream<DateTime>.periodic(
    const Duration(minutes: 1),
    (_) => DateTime.now(),
  );
});

final todaySnapshotProvider = Provider<TodaySnapshot>((ref) {
  final now = ref.watch(todayClockProvider).valueOrNull ?? DateTime.now();
  final activities =
      ref.watch(habitActivityListProvider).valueOrNull ?? const [];
  final logs =
      ref.watch(todayHabitLogListProvider).valueOrNull ?? const [];
  final habitEntries = buildTodayHabitEntries(
    activities: activities,
    logs: logs,
    date: now,
  );

  return buildTodaySnapshot(
    now: now,
    tasks: ref.watch(taskListProvider).valueOrNull ?? const [],
    projects: ref.watch(projectListProvider).valueOrNull ?? const [],
    events: ref.watch(calendarEventListProvider).valueOrNull ?? const [],
    habitDueCount: habitEntries.length,
    completedHabitCount:
        habitEntries.where((entry) => entry.completed).length,
  );
});

final todayCoreLoadingProvider = Provider<bool>((ref) {
  return ref.watch(taskListProvider).isLoading ||
      ref.watch(projectListProvider).isLoading ||
      ref.watch(calendarEventListProvider).isLoading ||
      ref.watch(habitActivityListProvider).isLoading ||
      ref.watch(todayHabitLogListProvider).isLoading;
});

final todayCoreErrorProvider = Provider<Object?>((ref) {
  final sources = [
    ref.watch(taskListProvider),
    ref.watch(projectListProvider),
    ref.watch(calendarEventListProvider),
    ref.watch(habitActivityListProvider),
    ref.watch(todayHabitLogListProvider),
  ];
  for (final source in sources) {
    if (source.hasError) return source.error;
  }
  return null;
});
