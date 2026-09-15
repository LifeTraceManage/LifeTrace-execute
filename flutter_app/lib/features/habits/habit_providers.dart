import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/background/background_sync.dart';
import '../../data/repository/habit_repository.dart';
import '../../data/sync/habit_conflict_resolver.dart';
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
  required DateTime date,
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
      .where(
        (activity) =>
            !activity.isArchived && _activityScheduledForDate(activity, date),
      )
      .map(
        (activity) => TodayHabitEntry(
          activity: activity,
          log: byActivity[activity.id],
        ),
      )
      .toList(growable: false);
}

bool _activityScheduledForDate(HabitActivity activity, DateTime date) {
  final local = date.toLocal();
  final startDate = activity.startDate;
  if (startDate != null && startDate.compareTo(habitDateKey(local)) > 0) {
    return false;
  }
  if (activity.targetDays.isNotEmpty &&
      !activity.targetDays.contains(local.weekday)) {
    return false;
  }
  return true;
}

final habitConflictResolverProvider =
    Provider<HabitConflictResolver?>((ref) {
  if (kIsWeb) return null;
  final database = ref.watch(appDatabaseProvider);
  return database == null ? null : HabitConflictResolver(database);
});

class HabitConflictUi {
  const HabitConflictUi({
    required this.conflictId,
    required this.entityType,
    required this.entityId,
    required this.reason,
    required this.serverDeleted,
  });

  final String conflictId;
  final String entityType;
  final String entityId;
  final String reason;
  final bool serverDeleted;
}

final habitConflictsProvider =
    StreamProvider<List<HabitConflictUi>>((ref) async* {
  if (kIsWeb) {
    yield const <HabitConflictUi>[];
    return;
  }
  final database = ref.watch(appDatabaseProvider);
  final userId = await ref.watch(currentUserIdProvider.future);
  if (database == null || userId == null) {
    yield const <HabitConflictUi>[];
    return;
  }

  final query = database.select(database.syncConflicts)
    ..where(
      (table) =>
          table.userId.equals(userId) &
          table.entityType.isIn(const [
            DriftHabitRepository.activityEntityType,
            DriftHabitRepository.logEntityType,
          ]) &
          table.resolved.equals(false),
    )
    ..orderBy([(table) => OrderingTerm.desc(table.createdAt)]);

  yield* query.watch().map(
        (rows) => rows
            .map(
              (row) => HabitConflictUi(
                conflictId: row.id,
                entityType: row.entityType,
                entityId: row.entityId,
                reason: row.reason,
                serverDeleted: row.serverDeleted,
              ),
            )
            .toList(growable: false),
      );
});

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

  Future<void> keepServer(String conflictId) async {
    final resolver = ref.read(habitConflictResolverProvider);
    if (resolver == null) return;
    await resolver.keepServer(conflictId);
    await ref.read(taskSyncControllerProvider.notifier).syncNow(silent: true);
  }

  Future<void> keepLocal(String conflictId) async {
    final resolver = ref.read(habitConflictResolverProvider);
    if (resolver == null) return;
    await resolver.keepLocal(
      conflictId: conflictId,
      deviceId: await ref.read(deviceIdProvider.future),
    );
    await ref.read(taskSyncControllerProvider.notifier).syncNow(silent: true);
    unawaited(BackgroundSyncScheduler.enqueueAfterLocalChange());
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
