import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repository/daily_review_repository.dart';
import '../../data/sync/daily_review_conflict_resolver.dart';
import '../../domain/review/daily_review.dart';
import '../tasks/task_providers.dart';

final dailyReviewRepositoryProvider = Provider<DailyReviewRepository>((ref) {
  if (kIsWeb) return PreviewDailyReviewRepository();
  final database = ref.watch(appDatabaseProvider);
  if (database == null) {
    throw StateError('Android production database is unavailable');
  }
  return DriftDailyReviewRepository(database);
});

String reviewDateKey(DateTime value) {
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

final todayReviewDateProvider =
    Provider<String>((ref) => reviewDateKey(DateTime.now()));

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

final dailyReviewConflictResolverProvider =
    Provider<DailyReviewConflictResolver?>((ref) {
  if (kIsWeb) return null;
  final database = ref.watch(appDatabaseProvider);
  return database == null ? null : DailyReviewConflictResolver(database);
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

final dailyReviewCommandsProvider =
    Provider<DailyReviewCommands>(DailyReviewCommands.new);

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
