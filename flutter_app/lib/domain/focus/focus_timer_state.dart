enum FocusMode {
  short('short', focusSeconds: 25 * 60, breakSeconds: 5 * 60),
  long('long', focusSeconds: 50 * 60, breakSeconds: 10 * 60);

  const FocusMode(
    this.wireValue, {
    required this.focusSeconds,
    required this.breakSeconds,
  });

  final String wireValue;
  final int focusSeconds;
  final int breakSeconds;

  static FocusMode fromWire(String value) => FocusMode.values.firstWhere(
        (item) => item.wireValue == value,
        orElse: () => FocusMode.short,
      );
}

enum FocusPhase {
  focus('focus'),
  breakTime('break');

  const FocusPhase(this.wireValue);
  final String wireValue;

  static FocusPhase fromWire(String value) => FocusPhase.values.firstWhere(
        (item) => item.wireValue == value,
        orElse: () => FocusPhase.focus,
      );
}

enum FocusTimerStatus {
  idle('idle'),
  running('running'),
  paused('paused');

  const FocusTimerStatus(this.wireValue);
  final String wireValue;

  static FocusTimerStatus fromWire(String value) =>
      FocusTimerStatus.values.firstWhere(
        (item) => item.wireValue == value,
        orElse: () => FocusTimerStatus.idle,
      );
}

class FocusTimerState {
  const FocusTimerState({
    required this.userId,
    required this.mode,
    required this.focusSeconds,
    required this.breakSeconds,
    required this.phase,
    required this.status,
    required this.remainingSecondsWhenPaused,
    required this.round,
    required this.updatedAt,
    this.startedAt,
    this.expectedEndAt,
    this.pausedAt,
    this.linkedTaskId,
    this.focusSessionId,
  });

  final String userId;
  final FocusMode mode;
  final int focusSeconds;
  final int breakSeconds;
  final FocusPhase phase;
  final FocusTimerStatus status;
  final String? startedAt;
  final String? expectedEndAt;
  final String? pausedAt;
  final int remainingSecondsWhenPaused;
  final String? linkedTaskId;
  final int round;

  /// Stable id reserved at focus start. It becomes the synced history id when
  /// the focus phase completes or is aborted, preventing duplicate histories.
  final String? focusSessionId;
  final String updatedAt;

  bool get isIdle => status == FocusTimerStatus.idle;
  bool get isRunning => status == FocusTimerStatus.running;
  bool get isPaused => status == FocusTimerStatus.paused;
  bool get isFocus => phase == FocusPhase.focus;
  bool get isBreak => phase == FocusPhase.breakTime;

  int get phaseTotalSeconds =>
      isFocus ? focusSeconds : breakSeconds;

  int remainingSeconds({DateTime? now}) {
    if (isIdle) return phaseTotalSeconds;
    if (isPaused) return remainingSecondsWhenPaused.clamp(0, phaseTotalSeconds);

    final end = DateTime.tryParse(expectedEndAt ?? '')?.toUtc();
    if (end == null) return 0;
    final current = (now ?? DateTime.now()).toUtc();
    final milliseconds = end.difference(current).inMilliseconds;
    if (milliseconds <= 0) return 0;
    return (milliseconds / 1000).ceil().clamp(0, phaseTotalSeconds);
  }

  double progress({DateTime? now}) {
    final total = phaseTotalSeconds;
    if (total <= 0) return 0;
    return ((total - remainingSeconds(now: now)) / total).clamp(0, 1);
  }

  FocusTimerState copyWith({
    FocusMode? mode,
    int? focusSeconds,
    int? breakSeconds,
    FocusPhase? phase,
    FocusTimerStatus? status,
    String? startedAt,
    String? expectedEndAt,
    String? pausedAt,
    int? remainingSecondsWhenPaused,
    String? linkedTaskId,
    int? round,
    String? focusSessionId,
    String? updatedAt,
    bool clearStartedAt = false,
    bool clearExpectedEndAt = false,
    bool clearPausedAt = false,
    bool clearLinkedTaskId = false,
    bool clearFocusSessionId = false,
  }) =>
      FocusTimerState(
        userId: userId,
        mode: mode ?? this.mode,
        focusSeconds: focusSeconds ?? this.focusSeconds,
        breakSeconds: breakSeconds ?? this.breakSeconds,
        phase: phase ?? this.phase,
        status: status ?? this.status,
        startedAt: clearStartedAt ? null : startedAt ?? this.startedAt,
        expectedEndAt:
            clearExpectedEndAt ? null : expectedEndAt ?? this.expectedEndAt,
        pausedAt: clearPausedAt ? null : pausedAt ?? this.pausedAt,
        remainingSecondsWhenPaused:
            remainingSecondsWhenPaused ?? this.remainingSecondsWhenPaused,
        linkedTaskId:
            clearLinkedTaskId ? null : linkedTaskId ?? this.linkedTaskId,
        round: round ?? this.round,
        focusSessionId: clearFocusSessionId
            ? null
            : focusSessionId ?? this.focusSessionId,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  static FocusTimerState idle({
    required String userId,
    FocusMode mode = FocusMode.short,
    String? linkedTaskId,
    int round = 1,
    String? updatedAt,
  }) =>
      FocusTimerState(
        userId: userId,
        mode: mode,
        focusSeconds: mode.focusSeconds,
        breakSeconds: mode.breakSeconds,
        phase: FocusPhase.focus,
        status: FocusTimerStatus.idle,
        remainingSecondsWhenPaused: mode.focusSeconds,
        linkedTaskId: linkedTaskId,
        round: round,
        updatedAt: updatedAt ?? DateTime.now().toUtc().toIso8601String(),
      );
}
