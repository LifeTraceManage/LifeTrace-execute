enum ExecutionProjectStatus {
  active('active'),
  paused('paused'),
  completed('completed'),
  archived('archived');

  const ExecutionProjectStatus(this.wireValue);
  final String wireValue;

  static ExecutionProjectStatus fromWire(String value) =>
      ExecutionProjectStatus.values.firstWhere(
        (status) => status.wireValue == value,
        orElse: () => ExecutionProjectStatus.active,
      );
}

class ExecutionProject {
  const ExecutionProject({
    required this.id,
    required this.userId,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.localVersion,
    this.description,
    this.status = ExecutionProjectStatus.active,
    this.startAt,
    this.dueAt,
    this.serverVersion,
    this.modifiedByDevice,
  });

  final String id;
  final String userId;
  final String title;
  final String? description;
  final ExecutionProjectStatus status;
  final String? startAt;
  final String? dueAt;
  final String createdAt;
  final String updatedAt;
  final int localVersion;
  final String? serverVersion;
  final String? modifiedByDevice;

  bool get isArchived => status == ExecutionProjectStatus.archived;
  bool get isCompleted => status == ExecutionProjectStatus.completed;

  ExecutionProject copyWith({
    String? title,
    String? description,
    ExecutionProjectStatus? status,
    String? startAt,
    String? dueAt,
    String? updatedAt,
    int? localVersion,
    String? serverVersion,
    String? modifiedByDevice,
    bool clearDescription = false,
    bool clearStartAt = false,
    bool clearDueAt = false,
  }) {
    return ExecutionProject(
      id: id,
      userId: userId,
      title: title ?? this.title,
      description: clearDescription ? null : description ?? this.description,
      status: status ?? this.status,
      startAt: clearStartAt ? null : startAt ?? this.startAt,
      dueAt: clearDueAt ? null : dueAt ?? this.dueAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      localVersion: localVersion ?? this.localVersion,
      serverVersion: serverVersion ?? this.serverVersion,
      modifiedByDevice: modifiedByDevice ?? this.modifiedByDevice,
    );
  }
}
