import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/background/background_sync.dart';
import '../../data/repository/habit_repository.dart';
import '../../domain/habit/habit.dart';
import '../tasks/task_providers.dart';

final habitRepositoryProvider = Provider<HabitRepository?>((ref) {
  if (kIsWeb) return null;
  final database = ref.watch(appDatabaseProvider);
  if (database == null) {
    throw StateError('Android production database is unavailable');
  }
  return DriftHabitRepository(database);
});

String habitDateKey(DateTime value) {
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

final todayHabitDateProvider =
    Provider<String>((ref) => habitDateKey(DateTime.now()));

final habitActivityListProvider =
    StreamProvider<List<HabitActivity>>((ref) async* {
  final repository = ref.watch(habitRepositoryProvider);
  final userId = await ref.watch(currentUserIdProvider.future);
  if (repository == null || userId == null) {
    yield const <HabitActivity>[];
    return;
  }
  yield* repository.watchActivities(userId);
});

final todayHabitLogListProvider =
    StreamProvider<List<HabitLog>>((ref) async* {
  final repository = ref.watch(habitRepositoryProvider);
  final userId = await ref.watch(currentUserIdProvider.future);
  if (repository == null || userId == null) {
    yield const <HabitLog>[];
    return;
  }
  yield* repository.watchLogsForDate(
    userId: userId,
    logDate: ref.watch(todayHabitDateProvider),
  );
});

class TodayHabitEntry {
  const TodayHabitEntry({
    required this.activity,
    required this.log,
  });

  final HabitActivity activity;
  final HabitLog? log;

  bool get completed => log?.status == HabitWireValues.logCompleted;
  double? get value => log?.value;
}

List<TodayHabitEntry> buildTodayHabitEntries({
  required List<HabitActivity> activities,
  required List<HabitLog> logs,
}) {
  final byActivity = <String, HabitLog>{};
  for (final log in logs) {
    final activityId = log.activityId;
    if (activityId == null) continue;
    final previous = byActivity[activityId];
    if (previous == null ||
        log.updatedAt.compareTo(previous.updatedAt) > 0) {
      byActivity[activityId] = log;
    }
  }

  return activities
      .where((activity) => !activity.isArchived)
      .map(
        (activity) => TodayHabitEntry(
          activity: activity,
          log: byActivity[activity.id],
        ),
      )
      .toList(growable: false);
}

final habitCommandsProvider = Provider<HabitCommands>(HabitCommands.new);

class HabitCommands {
  HabitCommands(this.ref);

  final Ref ref;

  Future<HabitLog?> toggleToday(TodayHabitEntry entry) async {
    final repository = ref.read(habitRepositoryProvider);
    if (repository == null) {
      throw StateError('Web preview does not persist habit data');
    }

    final existing = entry.log;
    if (existing != null && entry.completed) {
      await repository.deleteLog(log: existing);
      _scheduleSync();
      return null;
    }

    final activity = entry.activity;
    final log = await repository.upsertDailyLog(
      userId: activity.userId,
      deviceId: await ref.read(deviceIdProvider.future),
      activityId: activity.id,
      logDate: ref.read(todayHabitDateProvider),
      value: _completedValue(activity),
      status: HabitWireValues.logCompleted,
    );
    _scheduleSync();
    return log;
  }

  double _completedValue(HabitActivity activity) {
    if (activity.activityType == HabitWireValues.activityCompletion) return 1;
    return activity.normalTarget ?? activity.minimumTarget ?? 1;
  }

  void _scheduleSync() {
    if (kIsWeb) return;
    unawaited(
      ref.read(taskSyncControllerProvider.notifier).syncNow(silent: true),
    );
    unawaited(BackgroundSyncScheduler.enqueueAfterLocalChange());
  }
}
