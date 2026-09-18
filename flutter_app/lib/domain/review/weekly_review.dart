class WeeklyReview {
  const WeeklyReview({
    required this.id,
    required this.userId,
    required this.weekStart,
    required this.weekEnd,
    required this.createdAt,
    required this.updatedAt,
    required this.localVersion,
    this.completionScore,
    this.completedTaskCount,
    this.totalTaskCount,
    this.focusSeconds,
    this.completionSummary,
    this.bestThing,
    this.problem,
    this.improvement,
    this.nextWeekPriority,
    this.note,
    this.serverVersion,
    this.modifiedByDevice,
  });

  final String id;
  final String userId;
  final String weekStart;
  final String weekEnd;
  final double? completionScore;
  final int? completedTaskCount;
  final int? totalTaskCount;
  final int? focusSeconds;
  final String? completionSummary;
  final String? bestThing;
  final String? problem;
  final String? improvement;
  final String? nextWeekPriority;
  final String? note;
  final String createdAt;
  final String updatedAt;
  final int localVersion;
  final String? serverVersion;
  final String? modifiedByDevice;

  WeeklyReview copyWith({
    String? weekStart,
    String? weekEnd,
    double? completionScore,
    int? completedTaskCount,
    int? totalTaskCount,
    int? focusSeconds,
    String? completionSummary,
    String? bestThing,
    String? problem,
    String? improvement,
    String? nextWeekPriority,
    String? note,
    String? updatedAt,
    int? localVersion,
    String? serverVersion,
    String? modifiedByDevice,
    bool clearCompletionScore = false,
    bool clearCompletedTaskCount = false,
    bool clearTotalTaskCount = false,
    bool clearFocusSeconds = false,
    bool clearCompletionSummary = false,
    bool clearBestThing = false,
    bool clearProblem = false,
    bool clearImprovement = false,
    bool clearNextWeekPriority = false,
    bool clearNote = false,
  }) =>
      WeeklyReview(
        id: id,
        userId: userId,
        weekStart: weekStart ?? this.weekStart,
        weekEnd: weekEnd ?? this.weekEnd,
        completionScore: clearCompletionScore
            ? null
            : completionScore ?? this.completionScore,
        completedTaskCount: clearCompletedTaskCount
            ? null
            : completedTaskCount ?? this.completedTaskCount,
        totalTaskCount:
            clearTotalTaskCount ? null : totalTaskCount ?? this.totalTaskCount,
        focusSeconds:
            clearFocusSeconds ? null : focusSeconds ?? this.focusSeconds,
        completionSummary: clearCompletionSummary
            ? null
            : completionSummary ?? this.completionSummary,
        bestThing: clearBestThing ? null : bestThing ?? this.bestThing,
        problem: clearProblem ? null : problem ?? this.problem,
        improvement:
            clearImprovement ? null : improvement ?? this.improvement,
        nextWeekPriority: clearNextWeekPriority
            ? null
            : nextWeekPriority ?? this.nextWeekPriority,
        note: clearNote ? null : note ?? this.note,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        localVersion: localVersion ?? this.localVersion,
        serverVersion: serverVersion ?? this.serverVersion,
        modifiedByDevice: modifiedByDevice ?? this.modifiedByDevice,
      );
}
