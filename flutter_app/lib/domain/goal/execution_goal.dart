enum ExecutionGoalStatus {
  active('active'),
  paused('paused'),
  completed('completed'),
  cancelled('cancelled');

  const ExecutionGoalStatus(this.wireValue);
  final String wireValue;

  static ExecutionGoalStatus fromWire(String value) =>
      ExecutionGoalStatus.values.firstWhere(
        (status) => status.wireValue == value,
        orElse: () => ExecutionGoalStatus.active,
      );
}

class ExecutionGoal {
  const ExecutionGoal({
    required this.id,
    required this.userId,
    required this.name,
    required this.status,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
    required this.localVersion,
    this.description,
    this.targetAt,
    this.color,
    this.icon,
    this.completedAt,
    this.serverVersion,
    this.modifiedByDevice,
  });

  final String id;
  final String userId;
  final String name;
  final String? description;
  final ExecutionGoalStatus status;
  final String? targetAt;
  final String? color;
  final String? icon;
  final int sortOrder;
  final String? completedAt;
  final String createdAt;
  final String updatedAt;
  final int localVersion;
  final String? serverVersion;
  final String? modifiedByDevice;

  bool get isCompleted => status == ExecutionGoalStatus.completed;
  bool get isActive => status == ExecutionGoalStatus.active;

  ExecutionGoal copyWith({
    String? name,
    String? description,
    ExecutionGoalStatus? status,
    String? targetAt,
    String? color,
    String? icon,
    int? sortOrder,
    String? completedAt,
    String? updatedAt,
    int? localVersion,
    String? serverVersion,
    String? modifiedByDevice,
    bool clearDescription = false,
    bool clearTargetAt = false,
    bool clearColor = false,
    bool clearIcon = false,
    bool clearCompletedAt = false,
  }) =>
      ExecutionGoal(
        id: id,
        userId: userId,
        name: name ?? this.name,
        description:
            clearDescription ? null : description ?? this.description,
        status: status ?? this.status,
        targetAt: clearTargetAt ? null : targetAt ?? this.targetAt,
        color: clearColor ? null : color ?? this.color,
        icon: clearIcon ? null : icon ?? this.icon,
        sortOrder: sortOrder ?? this.sortOrder,
        completedAt:
            clearCompletedAt ? null : completedAt ?? this.completedAt,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        localVersion: localVersion ?? this.localVersion,
        serverVersion: serverVersion ?? this.serverVersion,
        modifiedByDevice: modifiedByDevice ?? this.modifiedByDevice,
      );
}
