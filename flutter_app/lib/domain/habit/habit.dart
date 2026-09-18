import 'dart:convert';

abstract final class HabitWireValues {
  static const activityDuration = 'duration';
  static const activityCount = 'count';
  static const activityCompletion = 'completion';
  static const activityWeekly = 'weekly';
  static const activityControl = 'control';
  static const scheduleDaily = 'daily';
  static const scheduleWeekly = 'weekly';
  static const scheduleCustom = 'custom';
  static const checkinManual = 'manual';
  static const checkinAutomatic = 'automatic';
  static const logCompleted = 'completed';
  static const logPartial = 'partial';
  static const logSkipped = 'skipped';
}

class HabitActivity {
  const HabitActivity({
    required this.id,
    required this.userId,
    required this.name,
    required this.activityType,
    required this.unit,
    required this.targetPeriod,
    required this.targetDays,
    required this.isArchived,
    required this.createdAt,
    required this.updatedAt,
    required this.localVersion,
    this.minimumTarget,
    this.normalTarget,
    this.icon,
    this.color,
    this.scheduleType,
    this.startDate,
    this.checkinMethod,
    this.syncSource,
    this.description,
    this.serverVersion,
    this.modifiedByDevice,
  });

  final String id;
  final String userId;
  final String name;
  final String activityType;
  final String unit;
  final double? minimumTarget;
  final double? normalTarget;
  final String targetPeriod;
  final List<int> targetDays;
  final String? icon;
  final String? color;
  final String? scheduleType;
  final String? startDate;
  final String? checkinMethod;
  final String? syncSource;
  final String? description;
  final bool isArchived;
  final String createdAt;
  final String updatedAt;
  final int localVersion;
  final String? serverVersion;
  final String? modifiedByDevice;

  HabitActivity copyWith({
    String? name,
    String? activityType,
    String? unit,
    double? minimumTarget,
    double? normalTarget,
    String? targetPeriod,
    List<int>? targetDays,
    String? icon,
    String? color,
    String? scheduleType,
    String? startDate,
    String? checkinMethod,
    String? syncSource,
    String? description,
    bool? isArchived,
    String? updatedAt,
    int? localVersion,
    String? serverVersion,
    String? modifiedByDevice,
    bool clearMinimumTarget = false,
    bool clearNormalTarget = false,
    bool clearIcon = false,
    bool clearColor = false,
    bool clearScheduleType = false,
    bool clearStartDate = false,
    bool clearCheckinMethod = false,
    bool clearSyncSource = false,
    bool clearDescription = false,
  }) =>
      HabitActivity(
        id: id,
        userId: userId,
        name: name ?? this.name,
        activityType: activityType ?? this.activityType,
        unit: unit ?? this.unit,
        minimumTarget:
            clearMinimumTarget ? null : minimumTarget ?? this.minimumTarget,
        normalTarget:
            clearNormalTarget ? null : normalTarget ?? this.normalTarget,
        targetPeriod: targetPeriod ?? this.targetPeriod,
        targetDays: targetDays ?? this.targetDays,
        icon: clearIcon ? null : icon ?? this.icon,
        color: clearColor ? null : color ?? this.color,
        scheduleType:
            clearScheduleType ? null : scheduleType ?? this.scheduleType,
        startDate: clearStartDate ? null : startDate ?? this.startDate,
        checkinMethod:
            clearCheckinMethod ? null : checkinMethod ?? this.checkinMethod,
        syncSource: clearSyncSource ? null : syncSource ?? this.syncSource,
        description:
            clearDescription ? null : description ?? this.description,
        isArchived: isArchived ?? this.isArchived,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        localVersion: localVersion ?? this.localVersion,
        serverVersion: serverVersion ?? this.serverVersion,
        modifiedByDevice: modifiedByDevice ?? this.modifiedByDevice,
      );
}

class HabitLog {
  const HabitLog({
    required this.id,
    required this.userId,
    required this.logDate,
    required this.createdAt,
    required this.updatedAt,
    required this.localVersion,
    this.activityId,
    this.value,
    this.status,
    this.note,
    this.metadata,
    this.serverVersion,
    this.modifiedByDevice,
  });

  final String id;
  final String userId;
  final String? activityId;
  final String logDate;
  final double? value;
  final String? status;
  final String? note;
  final Map<String, dynamic>? metadata;
  final String createdAt;
  final String updatedAt;
  final int localVersion;
  final String? serverVersion;
  final String? modifiedByDevice;

  HabitLog copyWith({
    String? activityId,
    String? logDate,
    double? value,
    String? status,
    String? note,
    Map<String, dynamic>? metadata,
    String? updatedAt,
    int? localVersion,
    String? serverVersion,
    String? modifiedByDevice,
    bool clearActivityId = false,
    bool clearValue = false,
    bool clearStatus = false,
    bool clearNote = false,
    bool clearMetadata = false,
  }) =>
      HabitLog(
        id: id,
        userId: userId,
        activityId: clearActivityId ? null : activityId ?? this.activityId,
        logDate: logDate ?? this.logDate,
        value: clearValue ? null : value ?? this.value,
        status: clearStatus ? null : status ?? this.status,
        note: clearNote ? null : note ?? this.note,
        metadata: clearMetadata ? null : metadata ?? this.metadata,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        localVersion: localVersion ?? this.localVersion,
        serverVersion: serverVersion ?? this.serverVersion,
        modifiedByDevice: modifiedByDevice ?? this.modifiedByDevice,
      );

  String? metadataJson() => metadata == null ? null : jsonEncode(metadata);
}
