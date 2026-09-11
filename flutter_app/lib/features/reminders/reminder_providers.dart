import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/background/background_sync.dart';
import '../../core/notifications/reminder_notification_service.dart';
import '../../data/repository/reminder_repository.dart';
import '../../data/sync/reminder_conflict_resolver.dart';
import '../../domain/reminder/execution_reminder.dart';
import '../tasks/task_providers.dart';

class ReminderSubjectKey {
  const ReminderSubjectKey({
    required this.subjectType,
    required this.subjectId,
  });

  final String subjectType;
  final String subjectId;

  @override
  bool operator ==(Object other) =>
      other is ReminderSubjectKey &&
      other.subjectType == subjectType &&
      other.subjectId == subjectId;

  @override
  int get hashCode => Object.hash(subjectType, subjectId);
}

class ReminderNotificationBridge {
  ReminderNotificationBridge() {
    service = ReminderNotificationService(onTap: _taps.add);
  }

  final StreamController<ReminderNotificationTarget> _taps =
      StreamController<ReminderNotificationTarget>.broadcast();

  late final ReminderNotificationService service;

  Stream<ReminderNotificationTarget> get taps => _taps.stream;

  void dispose() => _taps.close();
}

final reminderNotificationBridgeProvider =
    Provider<ReminderNotificationBridge>((ref) {
  final bridge = ReminderNotificationBridge();
  ref.onDispose(bridge.dispose);
  return bridge;
});

final reminderNotificationTapProvider =
    StreamProvider<ReminderNotificationTarget>((ref) {
  return ref.watch(reminderNotificationBridgeProvider).taps;
});

final reminderRepositoryProvider = Provider<ReminderRepository>((ref) {
  if (kIsWeb) return PreviewReminderRepository();
  final database = ref.watch(appDatabaseProvider);
  if (database == null) {
    throw StateError('Android production database is unavailable');
  }
  return DriftReminderRepository(database);
});

final reminderConflictResolverProvider =
    Provider<ReminderConflictResolver?>((ref) {
  if (kIsWeb) return null;
  final database = ref.watch(appDatabaseProvider);
  return database == null ? null : ReminderConflictResolver(database);
});

class ReminderConflictUi {
  const ReminderConflictUi({
    required this.conflictId,
    required this.reminderId,
    required this.reason,
    required this.serverDeleted,
  });

  final String conflictId;
  final String reminderId;
  final String reason;
  final bool serverDeleted;
}

final reminderConflictsProvider =
    StreamProvider<List<ReminderConflictUi>>((ref) async* {
  if (kIsWeb) {
    yield const <ReminderConflictUi>[];
    return;
  }
  final database = ref.watch(appDatabaseProvider);
  final userId = await ref.watch(currentUserIdProvider.future);
  if (database == null || userId == null) {
    yield const <ReminderConflictUi>[];
    return;
  }

  final query = database.select(database.syncConflicts)
    ..where(
      (table) =>
          table.userId.equals(userId) &
          table.entityType.equals(DriftReminderRepository.entityType) &
          table.resolved.equals(false),
    )
    ..orderBy([(table) => OrderingTerm.desc(table.createdAt)]);

  yield* query.watch().map(
        (rows) => rows
            .map(
              (row) => ReminderConflictUi(
                conflictId: row.id,
                reminderId: row.entityId,
                reason: row.reason,
                serverDeleted: row.serverDeleted,
              ),
            )
            .toList(growable: false),
      );
});

final reminderListProvider =
    StreamProvider<List<ExecutionReminder>>((ref) async* {
  final userId = await ref.watch(currentUserIdProvider.future);
  if (userId == null) {
    yield const <ExecutionReminder>[];
    return;
  }
  yield* ref.watch(reminderRepositoryProvider).watchReminders(userId);
});

final remindersForSubjectProvider = StreamProvider.family<
    List<ExecutionReminder>, ReminderSubjectKey>((ref, key) async* {
  final userId = await ref.watch(currentUserIdProvider.future);
  if (userId == null) {
    yield const <ExecutionReminder>[];
    return;
  }
  yield* ref.watch(reminderRepositoryProvider).watchForSubject(
        userId: userId,
        subjectType: key.subjectType,
        subjectId: key.subjectId,
      );
});

final reminderCommandsProvider =
    Provider<ReminderCommands>(ReminderCommands.new);

class ReminderCommands {
  ReminderCommands(this.ref);

  final Ref ref;

  Future<ExecutionReminder> schedule({
    required String subjectType,
    required String subjectId,
    required DateTime triggerAt,
    String? title,
    String? body,
  }) async {
    final bridge = ref.read(reminderNotificationBridgeProvider);
    final allowed = await bridge.service.requestPermission();
    if (!allowed) {
      throw StateError('通知权限未开启，无法创建系统提醒');
    }

    final userId = await _requireUserId();
    final repository = ref.read(reminderRepositoryProvider);
    final before = await repository.listForSubject(
      userId: userId,
      subjectType: subjectType,
      subjectId: subjectId,
    );
    final deviceId = await ref.read(deviceIdProvider.future);
    final reminder = await repository.schedule(
      userId: userId,
      deviceId: deviceId,
      subjectType: subjectType,
      subjectId: subjectId,
      triggerAt: triggerAt.toUtc().toIso8601String(),
      title: title,
      body: body,
    );

    for (final other in before) {
      if (other.id == reminder.id || !other.isScheduled) continue;
      await repository.cancel(reminder: other, deviceId: deviceId);
      await bridge.service.cancel(other.id);
    }

    await bridge.service.schedule(reminder);
    _scheduleSync();
    return reminder;
  }

  Future<ExecutionReminder> cancel(ExecutionReminder reminder) async {
    final cancelled = await ref.read(reminderRepositoryProvider).cancel(
          reminder: reminder,
          deviceId: await ref.read(deviceIdProvider.future),
        );
    await ref
        .read(reminderNotificationBridgeProvider)
        .service
        .cancel(reminder.id);
    _scheduleSync();
    return cancelled;
  }

  Future<void> cancelForSubject({
    required String subjectType,
    required String subjectId,
  }) async {
    final userId = await _requireUserId();
    final repository = ref.read(reminderRepositoryProvider);
    final reminders = await repository.listForSubject(
      userId: userId,
      subjectType: subjectType,
      subjectId: subjectId,
    );
    final deviceId = await ref.read(deviceIdProvider.future);
    var changed = false;
    for (final reminder in reminders) {
      if (!reminder.isScheduled) continue;
      changed = true;
      await repository.cancel(
        reminder: reminder,
        deviceId: deviceId,
      );
      await ref
          .read(reminderNotificationBridgeProvider)
          .service
          .cancel(reminder.id);
    }
    if (changed) _scheduleSync();
  }

  Future<void> delete(ExecutionReminder reminder) async {
    await ref.read(reminderRepositoryProvider).delete(
          userId: reminder.userId,
          reminderId: reminder.id,
        );
    await ref
        .read(reminderNotificationBridgeProvider)
        .service
        .cancel(reminder.id);
    _scheduleSync();
  }

  Future<void> keepServer(String conflictId) async {
    final resolver = ref.read(reminderConflictResolverProvider);
    if (resolver == null) return;
    await resolver.keepServer(conflictId);
    await reconcile();
    await ref.read(taskSyncControllerProvider.notifier).syncNow(silent: true);
  }

  Future<void> keepLocal(String conflictId) async {
    final resolver = ref.read(reminderConflictResolverProvider);
    if (resolver == null) return;
    await resolver.keepLocal(
      conflictId: conflictId,
      deviceId: await ref.read(deviceIdProvider.future),
    );
    await reconcile();
    await ref.read(taskSyncControllerProvider.notifier).syncNow(silent: true);
  }

  Future<void> reconcile() async {
    if (kIsWeb) return;
    final userId = await ref.read(currentUserIdProvider.future);
    if (userId == null) return;
    final reminders =
        await ref.read(reminderRepositoryProvider).listReminders(userId);
    await ref
        .read(reminderNotificationBridgeProvider)
        .service
        .reconcile(reminders);
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
