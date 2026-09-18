import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/background/background_sync.dart';
import '../../data/repository/important_date_repository.dart';
import '../../data/repository/reminder_repository.dart';
import '../../data/sync/important_date_conflict_resolver.dart';
import '../../data/sync/important_date_reminder_coordinator.dart';
import '../../domain/important_date/execution_important_date.dart';
import '../reminders/reminder_providers.dart';
import '../tasks/task_providers.dart';

final importantDateRepositoryProvider =
    Provider<ImportantDateRepository>((ref) {
  if (kIsWeb) return PreviewImportantDateRepository();
  final database = ref.watch(appDatabaseProvider);
  if (database == null) {
    throw StateError('Android production database is unavailable');
  }
  return DriftImportantDateRepository(database);
});

final importantDateListProvider =
    StreamProvider<List<ExecutionImportantDate>>((ref) async* {
  final userId = await ref.watch(currentUserIdProvider.future);
  if (userId == null) {
    yield const <ExecutionImportantDate>[];
    return;
  }
  yield* ref.watch(importantDateRepositoryProvider).watchImportantDates(userId);
});

final importantDateConflictResolverProvider =
    Provider<ImportantDateConflictResolver?>((ref) {
  if (kIsWeb) return null;
  final database = ref.watch(appDatabaseProvider);
  return database == null ? null : ImportantDateConflictResolver(database);
});

class ImportantDateConflictUi {
  const ImportantDateConflictUi({
    required this.conflictId,
    required this.importantDateId,
    required this.reason,
    required this.serverDeleted,
  });

  final String conflictId;
  final String importantDateId;
  final String reason;
  final bool serverDeleted;
}

final importantDateConflictsProvider =
    StreamProvider<List<ImportantDateConflictUi>>((ref) async* {
  if (kIsWeb) {
    yield const <ImportantDateConflictUi>[];
    return;
  }
  final database = ref.watch(appDatabaseProvider);
  final userId = await ref.watch(currentUserIdProvider.future);
  if (database == null || userId == null) {
    yield const <ImportantDateConflictUi>[];
    return;
  }

  final query = database.select(database.syncConflicts)
    ..where(
      (table) =>
          table.userId.equals(userId) &
          table.entityType.equals(DriftImportantDateRepository.entityType) &
          table.resolved.equals(false),
    )
    ..orderBy([(table) => OrderingTerm.desc(table.createdAt)]);

  yield* query.watch().map(
        (rows) => rows
            .map(
              (row) => ImportantDateConflictUi(
                conflictId: row.id,
                importantDateId: row.entityId,
                reason: row.reason,
                serverDeleted: row.serverDeleted,
              ),
            )
            .toList(growable: false),
      );
});

final importantDateCommandsProvider =
    Provider<ImportantDateCommands>(ImportantDateCommands.new);

class ImportantDateCommands {
  ImportantDateCommands(this.ref);

  final Ref ref;

  Future<ExecutionImportantDate> create({
    required String title,
    required ImportantDateRepeat repeat,
    required ImportantDateKind kind,
    required ImportantDateCalendar calendar,
    DateTime? solarDate,
    int? lunarYear,
    int? lunarMonth,
    int? lunarDay,
    bool lunarLeapMonth = false,
    bool enabled = true,
  }) async {
    final item =
        await ref.read(importantDateRepositoryProvider).createImportantDate(
              userId: await _requireUserId(),
              deviceId: await ref.read(deviceIdProvider.future),
              title: title,
              repeat: repeat,
              kind: kind,
              calendar: calendar,
              solarDate: solarDate,
              lunarYear: lunarYear,
              lunarMonth: lunarMonth,
              lunarDay: lunarDay,
              lunarLeapMonth: lunarLeapMonth,
              enabled: enabled,
            );
    _scheduleSync();
    return item;
  }

  Future<ExecutionImportantDate> update({
    required ExecutionImportantDate item,
    required String title,
    required ImportantDateRepeat repeat,
    required ImportantDateKind kind,
    required ImportantDateCalendar calendar,
    DateTime? solarDate,
    int? lunarYear,
    int? lunarMonth,
    int? lunarDay,
    bool lunarLeapMonth = false,
    required bool enabled,
  }) async {
    final updated =
        await ref.read(importantDateRepositoryProvider).updateImportantDate(
              item: item,
              deviceId: await ref.read(deviceIdProvider.future),
              title: title,
              repeat: repeat,
              kind: kind,
              calendar: calendar,
              solarDate: solarDate,
              lunarYear: lunarYear,
              lunarMonth: lunarMonth,
              lunarDay: lunarDay,
              lunarLeapMonth: lunarLeapMonth,
              enabled: enabled,
            );
    if (!updated.enabled) {
      await ref.read(reminderCommandsProvider).cancelForSubject(
            subjectType: ReminderSubjectTypes.importantDate,
            subjectId: updated.id,
          );
    }
    _scheduleSync();
    return updated;
  }

  Future<ExecutionImportantDate> setEnabled(
    ExecutionImportantDate item,
    bool enabled,
  ) {
    final solarDate = DateTime.tryParse(item.date);
    return update(
      item: item,
      title: item.title,
      repeat: item.repeat,
      kind: item.kind,
      calendar: item.calendar,
      solarDate:
          item.calendar == ImportantDateCalendar.solar ? solarDate : null,
      lunarYear: item.lunarYear,
      lunarMonth: item.lunarMonth,
      lunarDay: item.lunarDay,
      lunarLeapMonth: item.lunarLeapMonth,
      enabled: enabled,
    );
  }

  Future<void> delete(ExecutionImportantDate item) async {
    await ref.read(reminderCommandsProvider).cancelForSubject(
          subjectType: ReminderSubjectTypes.importantDate,
          subjectId: item.id,
        );
    await ref.read(importantDateRepositoryProvider).deleteImportantDate(
          userId: item.userId,
          importantDateId: item.id,
        );
    _scheduleSync();
  }

  Future<void> keepServer(ImportantDateConflictUi conflict) async {
    final resolver = ref.read(importantDateConflictResolverProvider);
    if (resolver == null) return;
    await resolver.keepServer(conflict.conflictId);
    if (conflict.serverDeleted) {
      await ref.read(reminderCommandsProvider).cancelForSubject(
            subjectType: ReminderSubjectTypes.importantDate,
            subjectId: conflict.importantDateId,
          );
    } else {
      await ref.read(reminderCommandsProvider).reconcile();
    }
    await ref.read(taskSyncControllerProvider.notifier).syncNow(silent: true);
  }

  Future<void> keepLocal(String conflictId) async {
    final resolver = ref.read(importantDateConflictResolverProvider);
    if (resolver == null) return;
    await resolver.keepLocal(
      conflictId: conflictId,
      deviceId: await ref.read(deviceIdProvider.future),
    );
    await ref.read(reminderCommandsProvider).reconcile();
    await ref.read(taskSyncControllerProvider.notifier).syncNow(silent: true);
    unawaited(BackgroundSyncScheduler.enqueueAfterLocalChange());
  }

  Future<int> reconcileRecurringReminders() async {
    if (kIsWeb) return 0;
    final userId = await ref.read(currentUserIdProvider.future);
    if (userId == null) return 0;
    final coordinator = ImportantDateReminderCoordinator(
      importantDates: ref.read(importantDateRepositoryProvider),
      reminders: ref.read(reminderRepositoryProvider),
    );
    final changed = await coordinator.reconcileYearlyFired(
      userId: userId,
      deviceId: await ref.read(deviceIdProvider.future),
    );
    if (changed > 0) {
      unawaited(BackgroundSyncScheduler.enqueueAfterLocalChange());
    }
    return changed;
  }

  Future<String> _requireUserId() async {
    final userId = await ref.read(currentUserIdProvider.future);
    if (userId == null) throw StateError('请先连接 LifeTrace Cloud');
    return userId;
  }

  void _scheduleSync() {
    if (kIsWeb) return;
    unawaited(
      ref.read(taskSyncControllerProvider.notifier).syncNow(silent: true),
    );
    unawaited(BackgroundSyncScheduler.enqueueAfterLocalChange());
  }
}
