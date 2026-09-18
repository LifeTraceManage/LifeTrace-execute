enum ExecutionReminderStatus {
  scheduled('scheduled'),
  fired('fired'),
  dismissed('dismissed'),
  cancelled('cancelled');

  const ExecutionReminderStatus(this.wireValue);
  final String wireValue;

  static ExecutionReminderStatus fromWire(String value) =>
      ExecutionReminderStatus.values.firstWhere(
        (item) => item.wireValue == value,
        orElse: () => ExecutionReminderStatus.scheduled,
      );
}

class ExecutionReminder {
  const ExecutionReminder({
    required this.id,
    required this.userId,
    required this.subjectType,
    required this.subjectId,
    required this.triggerAt,
    required this.status,
    required this.fireKey,
    required this.createdAt,
    required this.updatedAt,
    required this.localVersion,
    this.snoozedUntil,
    this.lastFiredAt,
    this.title,
    this.body,
    this.serverVersion,
    this.modifiedByDevice,
  });

  final String id;
  final String userId;
  final String subjectType;
  final String subjectId;
  final String triggerAt;
  final ExecutionReminderStatus status;
  final String fireKey;
  final String? snoozedUntil;
  final String? lastFiredAt;
  final String? title;
  final String? body;
  final String createdAt;
  final String updatedAt;
  final int localVersion;
  final String? serverVersion;
  final String? modifiedByDevice;

  bool get isScheduled => status == ExecutionReminderStatus.scheduled;

  String get effectiveTriggerAt => snoozedUntil ?? triggerAt;

  ExecutionReminder copyWith({
    String? triggerAt,
    ExecutionReminderStatus? status,
    String? fireKey,
    String? snoozedUntil,
    String? lastFiredAt,
    String? title,
    String? body,
    String? updatedAt,
    int? localVersion,
    String? serverVersion,
    String? modifiedByDevice,
    bool clearSnoozedUntil = false,
    bool clearLastFiredAt = false,
    bool clearTitle = false,
    bool clearBody = false,
  }) =>
      ExecutionReminder(
        id: id,
        userId: userId,
        subjectType: subjectType,
        subjectId: subjectId,
        triggerAt: triggerAt ?? this.triggerAt,
        status: status ?? this.status,
        fireKey: fireKey ?? this.fireKey,
        snoozedUntil:
            clearSnoozedUntil ? null : snoozedUntil ?? this.snoozedUntil,
        lastFiredAt:
            clearLastFiredAt ? null : lastFiredAt ?? this.lastFiredAt,
        title: clearTitle ? null : title ?? this.title,
        body: clearBody ? null : body ?? this.body,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        localVersion: localVersion ?? this.localVersion,
        serverVersion: serverVersion ?? this.serverVersion,
        modifiedByDevice: modifiedByDevice ?? this.modifiedByDevice,
      );
}
