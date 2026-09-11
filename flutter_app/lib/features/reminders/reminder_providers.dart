import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/background/background_sync.dart';
import '../../core/notifications/reminder_notification_service.dart';
import '../../data/repository/reminder_repository.dart';
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
    final reminder = await ref.read(reminderRepositoryProvider).schedule(
          userId: userId,
          deviceId: await ref.read(deviceIdProvider.future),
          subjectType: subjectType,
          subjectId: subjectId,
          triggerAt: triggerAt.toUtc().toIso8601String(),
          title: title,
          body: body,
        );
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
