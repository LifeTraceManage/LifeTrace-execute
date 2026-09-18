import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/background/background_sync.dart';
import '../../core/time/local_clock.dart';
import '../../data/repository/daily_review_repository.dart';
import '../../data/repository/weekly_review_repository.dart';
import '../../data/sync/daily_review_conflict_resolver.dart';
import '../../data/sync/weekly_review_conflict_resolver.dart';
import '../../domain/review/daily_review.dart';
import '../../domain/review/weekly_review.dart';
import '../tasks/task_providers.dart';
import 'weekly_review_stats.dart';

final dailyReviewRepositoryProvider = Provider<DailyReviewRepository>((ref) {
  if (kIsWeb) return PreviewDailyReviewRepository();
  final database = ref.watch(appDatabaseProvider);
  if (database == null) {
    throw StateError('Android production database is unavailable');
  }
  return DriftDailyReviewRepository(database);
});

final weeklyReviewRepositoryProvider = Provider<WeeklyReviewRepository>((ref) {
  if (kIsWeb) return PreviewWeeklyReviewRepository();
  final database = ref.watch(appDatabaseProvider);
  if (database == null) {
    throw StateError('Android production database is unavailable');
  }
  return DriftWeeklyReviewRepository(database);
});

String reviewDateKey(DateTime value) {
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

final todayReviewDateProvider = Provider<String>((ref) {
  final now = ref.watch(localMinuteClockProvider).valueOrNull ?? DateTime.now();
  return reviewDateKey(now);
});

final dailyReviewListProvider =
    StreamProvider<List<DailyReview>>((ref) async* {
  final repository = ref.watch(dailyReviewRepositoryProvider);
  final userId = await ref.watch(currentUserIdProvider.future);
  if (userId == null) {
    yield const <DailyReview>[];
    return;
  }
  yield* repository.watchReviews(userId);
});

final dailyReviewForDateProvider =
    StreamProvider.family<DailyReview?, String>((ref, reviewDate) async* {
  final repository = ref.watch(dailyReviewRepositoryProvider);
  final userId = await ref.watch(currentUserIdProvider.future);
  if (userId == null) {
    yield null;
    return;
  }
  yield* repository.watchReviewForDate(
    userId: userId,
    reviewDate: reviewDate,
  );
});

final currentReviewWeekProvider = Provider<ReviewWeekRange>((ref) {
  final now = ref.watch(localMinuteClockProvider).valueOrNull ?? DateTime.now();
  return reviewWeekFor(now);
});

final weeklyReviewListProvider =
    StreamProvider<List<WeeklyReview>>((ref) async* {
  final repository = ref.watch(weeklyReviewRepositoryProvider);
  final userId = await ref.watch(currentUserIdProvider.future);
  if (userId == null) {
    yield const <WeeklyReview>[];
    return;
  }
  yield* repository.watchReviews(userId);
});

final weeklyReviewForWeekProvider =
    StreamProvider.family<WeeklyReview?, String>((ref, weekStart) async* {
  final repository = ref.watch(weeklyReviewRepositoryProvider);
  final userId = await ref.watch(currentUserIdProvider.future);
  if (userId == null) {
    yield null;
    return;
  }
  yield* repository.watchReviewForWeek(
    userId: userId,
    weekStart: weekStart,
  );
});

final dailyReviewConflictResolverProvider =
    Provider<DailyReviewConflictResolver?>((ref) {
  if (kIsWeb) return null;
  final database = ref.watch(appDatabaseProvider);
  return database == null ? null : DailyReviewConflictResolver(database);
});

final weeklyReviewConflictResolverProvider =
    Provider<WeeklyReviewConflictResolver?>((ref) {
  if (kIsWeb) return null;
  final database = ref.watch(appDatabaseProvider);
  return database == null ? null : WeeklyReviewConflictResolver(database);
});

class DailyReviewConflictUi {
  const DailyReviewConflictUi({
    required this.conflictId,
    required this.reviewId,
    required this.reviewDate,
    required this.reason,
    required this.serverDeleted,
  });

  final String conflictId;
  final String reviewId;
  final String? reviewDate;
  final String reason;
  final bool serverDeleted;
}

final dailyReviewConflictsProvider =
    StreamProvider<List<DailyReviewConflictUi>>((ref) async* {
  if (kIsWeb) {
    yield const <DailyReviewConflictUi>[];
    return;
  }
  final database = ref.watch(appDatabaseProvider);
  final userId = await ref.watch(currentUserIdProvider.future);
  if (database == null || userId == null) {
    yield const <DailyReviewConflictUi>[];
    return;
  }

  final query = database.select(database.syncConflicts)
    ..where(
      (table) =>
          table.userId.equals(userId) &
          table.entityType.equals(DriftDailyReviewRepository.entityType) &
          table.resolved.equals(false),
    )
    ..orderBy([(table) => OrderingTerm.desc(table.createdAt)]);

  yield* query.watch().map(
        (rows) => rows
            .map(
              (row) => DailyReviewConflictUi(
                conflictId: row.id,
                reviewId: row.entityId,
                reviewDate: _reviewDateFromPayload(
                  row.localPayloadJson ?? row.serverPayloadJson,
                ),
                reason: row.reason,
                serverDeleted: row.serverDeleted,
              ),
            )
            .toList(growable: false),
      );
});

class WeeklyReviewConflictUi {
  const WeeklyReviewConflictUi({
    required this.conflictId,
    required this.reviewId,
    required this.weekStart,
    required this.reason,
    required this.serverDeleted,
  });

  final String conflictId;
  final String reviewId;
  final String? weekStart;
  final String reason;
  final bool serverDeleted;
}

final weeklyReviewConflictsProvider =
    StreamProvider<List<WeeklyReviewConflictUi>>((ref) async* {
  if (kIsWeb) {
    yield const <WeeklyReviewConflictUi>[];
    return;
  }
  final database = ref.watch(appDatabaseProvider);
  final userId = await ref.watch(currentUserIdProvider.future);
  if (database == null || userId == null) {
    yield const <WeeklyReviewConflictUi>[];
    return;
  }

  final query = database.select(database.syncConflicts)
    ..where(
      (table) =>
          table.userId.equals(userId) &
          table.entityType.equals(DriftWeeklyReviewRepository.entityType) &
          table.resolved.equals(false),
    )
    ..orderBy([(table) => OrderingTerm.desc(table.createdAt)]);

  yield* query.watch().map(
        (rows) => rows
            .map(
              (row) => WeeklyReviewConflictUi(
                conflictId: row.id,
                reviewId: row.entityId,
                weekStart: _weeklyStartFromPayload(
                  row.localPayloadJson ?? row.serverPayloadJson,
                ),
                reason: row.reason,
                serverDeleted: row.serverDeleted,
              ),
            )
            .toList(growable: false),
      );
});

final dailyReviewCommandsProvider =
    Provider<DailyReviewCommands>(DailyReviewCommands.new);

final weeklyReviewCommandsProvider =
    Provider<WeeklyReviewCommands>(WeeklyReviewCommands.new);

class DailyReviewCommands {
  DailyReviewCommands(this.ref);

  final Ref ref;

  Future<DailyReview> save({
    required String reviewDate,
    required int mood,
    required int energy,
    required int completedTaskCount,
    required int totalTaskCount,
    required double? completionScore,
    int? focusSeconds,
    String? bestThing,
    String? problem,
    String? tomorrowPriority,
    String? note,
  }) async {
    final userId = await ref.read(currentUserIdProvider.future);
    if (userId == null) throw StateError('请先连接 LifeTrace Cloud');

    final review = await ref.read(dailyReviewRepositoryProvider).saveReview(
          userId: userId,
          deviceId: await ref.read(deviceIdProvider.future),
          reviewDate: reviewDate,
          mood: mood,
          energy: energy,
          completionScore: completionScore,
          bestThing: bestThing,
          problem: problem,
          tomorrowPriority: tomorrowPriority,
          note: note,
          completedTaskCount: completedTaskCount,
          totalTaskCount: totalTaskCount,
          focusSeconds: focusSeconds,
        );
    _scheduleSync();
    return review;
  }

  Future<void> keepServer(String conflictId) async {
    final resolver = ref.read(dailyReviewConflictResolverProvider);
    if (resolver == null) return;
    await resolver.keepServer(conflictId);
    await ref.read(taskSyncControllerProvider.notifier).syncNow(silent: true);
  }

  Future<void> keepLocal(String conflictId) async {
    final resolver = ref.read(dailyReviewConflictResolverProvider);
    if (resolver == null) return;
    await resolver.keepLocal(
      conflictId: conflictId,
      deviceId: await ref.read(deviceIdProvider.future),
    );
    await ref.read(taskSyncControllerProvider.notifier).syncNow(silent: true);
  }

  void _scheduleSync() {
    if (kIsWeb) return;
    unawaited(
      ref.read(taskSyncControllerProvider.notifier).syncNow(silent: true),
    );
    unawaited(BackgroundSyncScheduler.enqueueAfterLocalChange());
  }
}

class WeeklyReviewCommands {
  WeeklyReviewCommands(this.ref);

  final Ref ref;

  Future<WeeklyReview> save({
    required String weekStart,
    required String weekEnd,
    required int completedTaskCount,
    required int totalTaskCount,
    required int focusSeconds,
    required double? completionScore,
    String? completionSummary,
    String? bestThing,
    String? problem,
    String? improvement,
    String? nextWeekPriority,
    String? note,
  }) async {
    final userId = await ref.read(currentUserIdProvider.future);
    if (userId == null) throw StateError('请先连接 LifeTrace Cloud');

    final review = await ref.read(weeklyReviewRepositoryProvider).saveReview(
          userId: userId,
          deviceId: await ref.read(deviceIdProvider.future),
          weekStart: weekStart,
          weekEnd: weekEnd,
          completionScore: completionScore,
          completedTaskCount: completedTaskCount,
          totalTaskCount: totalTaskCount,
          focusSeconds: focusSeconds,
          completionSummary: completionSummary,
          bestThing: bestThing,
          problem: problem,
          improvement: improvement,
          nextWeekPriority: nextWeekPriority,
          note: note,
        );
    _scheduleSync();
    return review;
  }

  Future<void> delete(WeeklyReview review) async {
    await ref.read(weeklyReviewRepositoryProvider).deleteReview(
          userId: review.userId,
          reviewId: review.id,
        );
    _scheduleSync();
  }

  Future<void> keepServer(String conflictId) async {
    final resolver = ref.read(weeklyReviewConflictResolverProvider);
    if (resolver == null) return;
    await resolver.keepServer(conflictId);
    await ref.read(taskSyncControllerProvider.notifier).syncNow(silent: true);
  }

  Future<void> keepLocal(String conflictId) async {
    final resolver = ref.read(weeklyReviewConflictResolverProvider);
    if (resolver == null) return;
    await resolver.keepLocal(
      conflictId: conflictId,
      deviceId: await ref.read(deviceIdProvider.future),
    );
    await ref.read(taskSyncControllerProvider.notifier).syncNow(silent: true);
    if (!kIsWeb) {
      unawaited(BackgroundSyncScheduler.enqueueAfterLocalChange());
    }
  }

  void _scheduleSync() {
    if (kIsWeb) return;
    unawaited(
      ref.read(taskSyncControllerProvider.notifier).syncNow(silent: true),
    );
    unawaited(BackgroundSyncScheduler.enqueueAfterLocalChange());
  }
}

String? _reviewDateFromPayload(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final value = jsonDecode(raw);
    if (value is! Map) return null;
    final date = value['reviewDate']?.toString().trim();
    return date == null || date.isEmpty ? null : date;
  } catch (_) {
    return null;
  }
}


String? _weeklyStartFromPayload(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final value = jsonDecode(raw);
    if (value is! Map) return null;
    final start = value['weekStart']?.toString().trim();
    return start == null || start.isEmpty ? null : start;
  } catch (_) {
    return null;
  }
}
