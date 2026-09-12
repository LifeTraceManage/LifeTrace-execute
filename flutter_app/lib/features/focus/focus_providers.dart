import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/background/background_sync.dart';
import '../../data/focus/focus_timer_engine.dart';
import '../../data/repository/focus_repository.dart';
import '../../data/sync/focus_session_conflict_resolver.dart';
import '../../domain/focus/execution_focus_session.dart';
import '../../domain/focus/focus_timer_state.dart';
import '../reminders/reminder_providers.dart';
import '../tasks/task_providers.dart';
import 'focus_stats.dart';

final focusRepositoryProvider = Provider<FocusRepository>((ref) {
  if (kIsWeb) return PreviewFocusRepository();
  final database = ref.watch(appDatabaseProvider);
  if (database == null) {
    throw StateError('Android production database is unavailable');
  }
  return DriftFocusRepository(database);
});

final focusTimerStateProvider =
    StreamProvider<FocusTimerState?>((ref) async* {
  final userId = await ref.watch(currentUserIdProvider.future);
  if (userId == null) {
    yield null;
    return;
  }
  yield* ref.watch(focusRepositoryProvider).watchTimerState(userId);
});

final focusSessionListProvider =
    StreamProvider<List<ExecutionFocusSession>>((ref) async* {
  final userId = await ref.watch(currentUserIdProvider.future);
  if (userId == null) {
    yield const <ExecutionFocusSession>[];
    return;
  }
  yield* ref.watch(focusRepositoryProvider).watchSessions(userId);
});

final focusTodayStatsProvider = Provider<FocusTodayStats>((ref) {
  final sessions =
      ref.watch(focusSessionListProvider).valueOrNull ??
          const <ExecutionFocusSession>[];
  return calculateFocusTodayStats(sessions);
});

final focusConflictResolverProvider =
    Provider<FocusSessionConflictResolver?>((ref) {
  if (kIsWeb) return null;
  final database = ref.watch(appDatabaseProvider);
  return database == null ? null : FocusSessionConflictResolver(database);
});

class FocusSessionConflictUi {
  const FocusSessionConflictUi({
    required this.conflictId,
    required this.sessionId,
    required this.reason,
    required this.serverDeleted,
  });

  final String conflictId;
  final String sessionId;
  final String reason;
  final bool serverDeleted;
}

final focusSessionConflictsProvider =
    StreamProvider<List<FocusSessionConflictUi>>((ref) async* {
  if (kIsWeb) {
    yield const <FocusSessionConflictUi>[];
    return;
  }
  final database = ref.watch(appDatabaseProvider);
  final userId = await ref.watch(currentUserIdProvider.future);
  if (database == null || userId == null) {
    yield const <FocusSessionConflictUi>[];
    return;
  }

  final query = database.select(database.syncConflicts)
    ..where(
      (table) =>
          table.userId.equals(userId) &
          table.entityType.equals(DriftFocusRepository.entityType) &
          table.resolved.equals(false),
    )
    ..orderBy([(table) => OrderingTerm.desc(table.createdAt)]);

  yield* query.watch().map(
        (rows) => rows
            .map(
              (row) => FocusSessionConflictUi(
                conflictId: row.id,
                sessionId: row.entityId,
                reason: row.reason,
                serverDeleted: row.serverDeleted,
              ),
            )
            .toList(growable: false),
      );
});

final focusCommandsProvider = Provider<FocusCommands>(FocusCommands.new);

class FocusCommands {
  FocusCommands(this.ref);

  final Ref ref;

  FocusTimerEngine get _engine =>
      FocusTimerEngine(repository: ref.read(focusRepositoryProvider));

  Future<FocusTimerState> initialize({String? linkedTaskId}) async {
    final userId = await _requireUserId();
    var state = await _engine.ensureState(
      userId: userId,
      linkedTaskId: linkedTaskId,
    );
    state = await _engine.reconcile(
      userId: userId,
      deviceId: await ref.read(deviceIdProvider.future),
    );
    if (linkedTaskId != null &&
        state.isIdle &&
        state.linkedTaskId != linkedTaskId) {
      state = await _engine.linkTask(userId: userId, taskId: linkedTaskId);
    }
    await _reconcileNotification(state);
    _scheduleSync();
    return state;
  }

  Future<FocusTimerState> setMode(FocusMode mode) async {
    final state = await _engine.configureMode(
      userId: await _requireUserId(),
      mode: mode,
    );
    await _reconcileNotification(state);
    return state;
  }

  Future<FocusTimerState> linkTask(String? taskId) async {
    final state = await _engine.linkTask(
      userId: await _requireUserId(),
      taskId: taskId,
    );
    return state;
  }

  Future<FocusTimerState> start({String? linkedTaskId}) async {
    if (!kIsWeb) {
      await ref
          .read(reminderNotificationBridgeProvider)
          .service
          .requestPermission();
    }
    final state = await _engine.start(
      userId: await _requireUserId(),
      deviceId: await ref.read(deviceIdProvider.future),
      linkedTaskId: linkedTaskId,
    );
    await _reconcileNotification(state);
    _scheduleSync();
    return state;
  }

  Future<FocusTimerState> pause() async {
    final state = await _engine.pause(
      userId: await _requireUserId(),
      deviceId: await ref.read(deviceIdProvider.future),
    );
    await _reconcileNotification(state);
    _scheduleSync();
    return state;
  }

  Future<FocusTimerState> resume() async {
    final state = await _engine.resume(userId: await _requireUserId());
    await _reconcileNotification(state);
    return state;
  }

  Future<FocusTimerState> reset() async {
    final state = await _engine.reset(
      userId: await _requireUserId(),
      deviceId: await ref.read(deviceIdProvider.future),
    );
    await _reconcileNotification(state);
    _scheduleSync();
    return state;
  }

  Future<FocusTimerState> skip() async {
    final state = await _engine.skip(
      userId: await _requireUserId(),
      deviceId: await ref.read(deviceIdProvider.future),
    );
    await _reconcileNotification(state);
    _scheduleSync();
    return state;
  }

  Future<FocusTimerState?> reconcile() async {
    final userId = await ref.read(currentUserIdProvider.future);
    if (userId == null) return null;
    final state = await _engine.reconcile(
      userId: userId,
      deviceId: await ref.read(deviceIdProvider.future),
    );
    await _reconcileNotification(state);
    _scheduleSync();
    return state;
  }

  Future<void> keepServer(String conflictId) async {
    final resolver = ref.read(focusConflictResolverProvider);
    if (resolver == null) return;
    await resolver.keepServer(conflictId);
    await ref.read(taskSyncControllerProvider.notifier).syncNow(silent: true);
  }

  Future<void> keepLocal(String conflictId) async {
    final resolver = ref.read(focusConflictResolverProvider);
    if (resolver == null) return;
    await resolver.keepLocal(
      conflictId: conflictId,
      deviceId: await ref.read(deviceIdProvider.future),
    );
    await ref.read(taskSyncControllerProvider.notifier).syncNow(silent: true);
    unawaited(BackgroundSyncScheduler.enqueueAfterLocalChange());
  }

  Future<void> _reconcileNotification(FocusTimerState state) async {
    if (kIsWeb) return;
    await ref
        .read(reminderNotificationBridgeProvider)
        .service
        .reconcileFocus(state);
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
