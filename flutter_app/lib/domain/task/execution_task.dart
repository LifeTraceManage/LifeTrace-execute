enum ExecutionTaskStatus {
  todo('todo'),
  inProgress('in_progress'),
  waiting('waiting'),
  done('done');

  const ExecutionTaskStatus(this.wireValue);
  final String wireValue;

  static ExecutionTaskStatus fromWire(String value) =>
      ExecutionTaskStatus.values.firstWhere(
        (status) => status.wireValue == value,
        orElse: () => ExecutionTaskStatus.todo,
      );
}

enum ExecutionTaskPriority {
  low('low'),
  normal('normal'),
  high('high'),
  urgent('urgent');

  const ExecutionTaskPriority(this.wireValue);
  final String wireValue;

  static ExecutionTaskPriority fromWire(String value) =>
      ExecutionTaskPriority.values.firstWhere(
        (priority) => priority.wireValue == value,
        orElse: () => ExecutionTaskPriority.normal,
      );
}

class ExecutionTask {
  const ExecutionTask({
    required this.id,
    required this.userId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.localVersion,
    this.description,
    this.projectId,
    this.status = ExecutionTaskStatus.todo,
    this.priority = ExecutionTaskPriority.normal,
    this.dueAt,
    this.scheduledAt,
    this.completedAt,
    this.serverVersion,
    this.modifiedByDevice,
  });

  final String id;
  final String userId;
  final String title;
  final String? description;
  final String? projectId;
  final ExecutionTaskStatus status;
  final ExecutionTaskPriority priority;
  final String? dueAt;
  final String? scheduledAt;
  final String? completedAt;
  final String createdAt;
  final String updatedAt;
  final int localVersion;
  final String? serverVersion;
  final String? modifiedByDevice;

  bool get isDone => status == ExecutionTaskStatus.done;

  ExecutionTask copyWith({
    String? title,
    String? description,
    String? projectId,
    ExecutionTaskStatus? status,
    ExecutionTaskPriority? priority,
    String? dueAt,
    String? scheduledAt,
    String? completedAt,
    String? updatedAt,
    int? localVersion,
    String? serverVersion,
    String? modifiedByDevice,
    bool clearDescription = false,
    bool clearProjectId = false,
    bool clearDueAt = false,
    bool clearScheduledAt = false,
    bool clearCompletedAt = false,
  }) {
    return ExecutionTask(
      id: id,
      userId: userId,
      title: title ?? this.title,
      description: clearDescription ? null : description ?? this.description,
      projectId: clearProjectId ? null : projectId ?? this.projectId,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      dueAt: clearDueAt ? null : dueAt ?? this.dueAt,
      scheduledAt: clearScheduledAt ? null : scheduledAt ?? this.scheduledAt,
      completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      localVersion: localVersion ?? this.localVersion,
      serverVersion: serverVersion ?? this.serverVersion,
      modifiedByDevice: modifiedByDevice ?? this.modifiedByDevice,
    );
  }
}
