import 'package:uuid/uuid.dart';

import '../../domain/focus/execution_focus_session.dart';
import '../../domain/focus/focus_timer_state.dart';
import '../repository/focus_repository.dart';

typedef FocusClock = DateTime Function();

class FocusTimerEngine {
  FocusTimerEngine({
    required this.repository,
    Uuid? uuid,
    FocusClock? clock,
  })  : _uuid = uuid ?? const Uuid(),
        _clock = clock ?? DateTime.now;

  final FocusRepository repository;
  final Uuid _uuid;
  final FocusClock _clock;

  Future<FocusTimerState> ensureState({
    required String userId,
    String? linkedTaskId,
  }) async {
    final existing = await repository.getTimerState(userId);
    if (existing != null) {
      if (linkedTaskId != null &&
          existing.isIdle &&
          existing.linkedTaskId != linkedTaskId) {
        final updated = existing.copyWith(
          linkedTaskId: linkedTaskId,
          updatedAt: _nowIso(),
        );
        await repository.saveTimerState(updated);
        return updated;
      }
      return existing;
    }
    final created = FocusTimerState.idle(
      userId: userId,
      linkedTaskId: linkedTaskId,
      updatedAt: _nowIso(),
    );
    await repository.saveTimerState(created);
    return created;
  }

  Future<FocusTimerState> configureMode({
    required String userId,
    required FocusMode mode,
  }) async {
    final current = await ensureState(userId: userId);
    if (!current.isIdle) {
      throw StateError('计时进行中时不能切换番茄模式');
    }
    final updated = current.copyWith(
      mode: mode,
      focusSeconds: mode.focusSeconds,
      breakSeconds: mode.breakSeconds,
      phase: FocusPhase.focus,
      remainingSecondsWhenPaused: mode.focusSeconds,
      clearStartedAt: true,
      clearExpectedEndAt: true,
      clearPausedAt: true,
      clearFocusSessionId: true,
      updatedAt: _nowIso(),
    );
    await repository.saveTimerState(updated);
    return updated;
  }

  Future<FocusTimerState> linkTask({
    required String userId,
    String? taskId,
  }) async {
    final current = await ensureState(userId: userId);
    if (!current.isIdle) {
      throw StateError('计时进行中时不能切换关联任务');
    }
    final updated = current.copyWith(
      linkedTaskId: taskId,
      clearLinkedTaskId: taskId == null,
      updatedAt: _nowIso(),
    );
    await repository.saveTimerState(updated);
    return updated;
  }

  Future<FocusTimerState> start({
    required String userId,
    String? linkedTaskId,
  }) async {
    var current = await ensureState(
      userId: userId,
      linkedTaskId: linkedTaskId,
    );
    current = await reconcile(userId: userId, deviceId: 'recovery');

    if (current.isPaused) {
      return resume(userId: userId);
    }
    if (current.isRunning) return current;

    final now = _clock().toUtc();
    final duration = Duration(seconds: current.focusSeconds);
    final updated = current.copyWith(
      phase: FocusPhase.focus,
      status: FocusTimerStatus.running,
      startedAt: now.toIso8601String(),
      expectedEndAt: now.add(duration).toIso8601String(),
      clearPausedAt: true,
      remainingSecondsWhenPaused: current.focusSeconds,
      focusSessionId: _uuid.v4(),
      linkedTaskId: linkedTaskId,
      updatedAt: now.toIso8601String(),
    );
    await repository.saveTimerState(updated);
    return updated;
  }

  Future<FocusTimerState> pause({
    required String userId,
    required String deviceId,
  }) async {
    var current = await reconcile(userId: userId, deviceId: deviceId);
    if (!current.isRunning) return current;

    final now = _clock().toUtc();
    final remaining = current.remainingSeconds(now: now);
    if (remaining <= 0) {
      return reconcile(userId: userId, deviceId: deviceId);
    }

    final updated = current.copyWith(
      status: FocusTimerStatus.paused,
      pausedAt: now.toIso8601String(),
      remainingSecondsWhenPaused: remaining,
      clearExpectedEndAt: true,
      updatedAt: now.toIso8601String(),
    );
    await repository.saveTimerState(updated);
    return updated;
  }

  Future<FocusTimerState> resume({required String userId}) async {
    final current = await ensureState(userId: userId);
    if (!current.isPaused) return current;

    final remaining = current.remainingSecondsWhenPaused.clamp(
      1,
      current.phaseTotalSeconds,
    );
    final now = _clock().toUtc();
    final updated = current.copyWith(
      status: FocusTimerStatus.running,
      expectedEndAt:
          now.add(Duration(seconds: remaining)).toIso8601String(),
      clearPausedAt: true,
      remainingSecondsWhenPaused: remaining,
      updatedAt: now.toIso8601String(),
    );
    await repository.saveTimerState(updated);
    return updated;
  }

  Future<FocusTimerState> reset({
    required String userId,
    required String deviceId,
  }) async {
    var current = await reconcile(userId: userId, deviceId: deviceId);
    if (current.isIdle) {
      final reset = FocusTimerState.idle(
        userId: userId,
        mode: current.mode,
        linkedTaskId: current.linkedTaskId,
        round: current.round,
        updatedAt: _nowIso(),
      );
      await repository.saveTimerState(reset);
      return reset;
    }

    if (current.isFocus) {
      current = await _finishFocus(
        current,
        deviceId: deviceId,
        completed: false,
        startBreak: false,
      );
      return current;
    }

    final idle = FocusTimerState.idle(
      userId: userId,
      mode: current.mode,
      linkedTaskId: current.linkedTaskId,
      round: current.round + 1,
      updatedAt: _nowIso(),
    );
    await repository.saveTimerState(idle);
    return idle;
  }

  Future<FocusTimerState> skip({
    required String userId,
    required String deviceId,
  }) async {
    var current = await reconcile(userId: userId, deviceId: deviceId);
    if (current.isIdle) return current;

    if (current.isFocus) {
      return _finishFocus(
        current,
        deviceId: deviceId,
        completed: false,
        startBreak: true,
      );
    }

    final idle = FocusTimerState.idle(
      userId: userId,
      mode: current.mode,
      linkedTaskId: current.linkedTaskId,
      round: current.round + 1,
      updatedAt: _nowIso(),
    );
    await repository.saveTimerState(idle);
    return idle;
  }

  Future<FocusTimerState> reconcile({
    required String userId,
    required String deviceId,
  }) async {
    var current = await ensureState(userId: userId);
    if (!current.isRunning) return current;

    var guard = 0;
    while (current.isRunning && guard++ < 3) {
      final now = _clock().toUtc();
      final end = DateTime.tryParse(current.expectedEndAt ?? '')?.toUtc();
      if (end == null || end.isAfter(now)) break;

      if (current.isFocus) {
        current = await _finishFocus(
          current,
          deviceId: deviceId,
          completed: true,
          startBreak: true,
          endedAt: end,
        );
        continue;
      }

      final idle = FocusTimerState.idle(
        userId: current.userId,
        mode: current.mode,
        linkedTaskId: current.linkedTaskId,
        round: current.round + 1,
        updatedAt: now.toIso8601String(),
      );
      await repository.saveTimerState(idle);
      current = idle;
    }
    return current;
  }

  Future<FocusTimerState> _finishFocus(
    FocusTimerState current, {
    required String deviceId,
    required bool completed,
    required bool startBreak,
    DateTime? endedAt,
  }) async {
    final now = (endedAt ?? _clock()).toUtc();
    final remaining = completed ? 0 : current.remainingSeconds(now: now);
    final elapsed = (current.focusSeconds - remaining)
        .clamp(0, current.focusSeconds);
    final sessionId = current.focusSessionId ?? _uuid.v4();

    final nextState = startBreak
        ? current.copyWith(
            phase: FocusPhase.breakTime,
            status: FocusTimerStatus.running,
            startedAt: now.toIso8601String(),
            expectedEndAt: now
                .add(Duration(seconds: current.breakSeconds))
                .toIso8601String(),
            clearPausedAt: true,
            remainingSecondsWhenPaused: current.breakSeconds,
            clearFocusSessionId: true,
            updatedAt: now.toIso8601String(),
          )
        : FocusTimerState.idle(
            userId: current.userId,
            mode: current.mode,
            linkedTaskId: current.linkedTaskId,
            round: current.round,
            updatedAt: now.toIso8601String(),
          );

    if (elapsed == 0 && !completed) {
      await repository.saveTimerState(nextState);
      return nextState;
    }

    final originalStart = DateTime.tryParse(current.startedAt ?? '')?.toUtc() ??
        now.subtract(Duration(seconds: elapsed));
    final session = ExecutionFocusSession(
      id: sessionId,
      userId: current.userId,
      taskId: current.linkedTaskId,
      mode: current.mode,
      startedAt: originalStart.toIso8601String(),
      endedAt: now.toIso8601String(),
      focusSeconds: completed ? current.focusSeconds : elapsed,
      completed: completed,
      createdAt: now.toIso8601String(),
      updatedAt: now.toIso8601String(),
      localVersion: 1,
      modifiedByDevice: deviceId,
    );
    await repository.recordSessionAndSaveState(
      session: session,
      nextState: nextState,
    );
    return nextState;
  }

  String _nowIso() => _clock().toUtc().toIso8601String();
}
