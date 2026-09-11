class DailyReview {
  const DailyReview({
    required this.id,
    required this.userId,
    required this.reviewDate,
    required this.createdAt,
    required this.updatedAt,
    required this.localVersion,
    this.energy,
    this.mood,
    this.completionScore,
    this.bestThing,
    this.problem,
    this.tomorrowPriority,
    this.note,
    this.completedTaskCount,
    this.totalTaskCount,
    this.serverVersion,
    this.modifiedByDevice,
  });

  final String id;
  final String userId;
  final String reviewDate;
  final int? energy;
  final int? mood;
  final double? completionScore;
  final String? bestThing;
  final String? problem;
  final String? tomorrowPriority;
  final String? note;
  final int? completedTaskCount;
  final int? totalTaskCount;
  final String createdAt;
  final String updatedAt;
  final int localVersion;
  final String? serverVersion;
  final String? modifiedByDevice;

  DailyReview copyWith({
    int? energy,
    int? mood,
    double? completionScore,
    String? bestThing,
    String? problem,
    String? tomorrowPriority,
    String? note,
    int? completedTaskCount,
    int? totalTaskCount,
    String? updatedAt,
    int? localVersion,
    String? serverVersion,
    String? modifiedByDevice,
    bool clearEnergy = false,
    bool clearMood = false,
    bool clearCompletionScore = false,
    bool clearBestThing = false,
    bool clearProblem = false,
    bool clearTomorrowPriority = false,
    bool clearNote = false,
    bool clearCompletedTaskCount = false,
    bool clearTotalTaskCount = false,
  }) =>
      DailyReview(
        id: id,
        userId: userId,
        reviewDate: reviewDate,
        energy: clearEnergy ? null : energy ?? this.energy,
        mood: clearMood ? null : mood ?? this.mood,
        completionScore: clearCompletionScore
            ? null
            : completionScore ?? this.completionScore,
        bestThing: clearBestThing ? null : bestThing ?? this.bestThing,
        problem: clearProblem ? null : problem ?? this.problem,
        tomorrowPriority: clearTomorrowPriority
            ? null
            : tomorrowPriority ?? this.tomorrowPriority,
        note: clearNote ? null : note ?? this.note,
        completedTaskCount: clearCompletedTaskCount
            ? null
            : completedTaskCount ?? this.completedTaskCount,
        totalTaskCount:
            clearTotalTaskCount ? null : totalTaskCount ?? this.totalTaskCount,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        localVersion: localVersion ?? this.localVersion,
        serverVersion: serverVersion ?? this.serverVersion,
        modifiedByDevice: modifiedByDevice ?? this.modifiedByDevice,
      );
}
