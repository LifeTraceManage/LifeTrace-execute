import '../focus/focus_timer_state.dart';

class ExecutionFocusSession {
  const ExecutionFocusSession({
    required this.id,
    required this.userId,
    required this.mode,
    required this.startedAt,
    required this.endedAt,
    required this.focusSeconds,
    required this.completed,
    required this.createdAt,
    required this.updatedAt,
    required this.localVersion,
    this.taskId,
    this.serverVersion,
    this.modifiedByDevice,
  });

  final String id;
  final String userId;
  final String? taskId;
  final FocusMode mode;
  final String startedAt;
  final String endedAt;
  final int focusSeconds;
  final bool completed;

  final String createdAt;
  final String updatedAt;
  final int localVersion;
  final String? serverVersion;
  final String? modifiedByDevice;

  ExecutionFocusSession copyWith({
    String? taskId,
    FocusMode? mode,
    String? startedAt,
    String? endedAt,
    int? focusSeconds,
    bool? completed,
    String? updatedAt,
    int? localVersion,
    String? serverVersion,
    String? modifiedByDevice,
    bool clearTaskId = false,
  }) =>
      ExecutionFocusSession(
        id: id,
        userId: userId,
        taskId: clearTaskId ? null : taskId ?? this.taskId,
        mode: mode ?? this.mode,
        startedAt: startedAt ?? this.startedAt,
        endedAt: endedAt ?? this.endedAt,
        focusSeconds: focusSeconds ?? this.focusSeconds,
        completed: completed ?? this.completed,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        localVersion: localVersion ?? this.localVersion,
        serverVersion: serverVersion ?? this.serverVersion,
        modifiedByDevice: modifiedByDevice ?? this.modifiedByDevice,
      );
}
