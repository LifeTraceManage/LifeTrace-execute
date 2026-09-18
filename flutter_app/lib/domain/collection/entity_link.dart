class ExecutionEntityLink {
  const ExecutionEntityLink({
    required this.id,
    required this.userId,
    required this.sourceType,
    required this.sourceId,
    required this.targetType,
    required this.targetId,
    required this.relationType,
    required this.createdAt,
    required this.updatedAt,
    required this.localVersion,
    this.metadata,
    this.serverVersion,
    this.modifiedByDevice,
  });

  final String id;
  final String userId;
  final String sourceType;
  final String sourceId;
  final String targetType;
  final String targetId;
  final String relationType;
  final Map<String, dynamic>? metadata;
  final String createdAt;
  final String updatedAt;
  final int localVersion;
  final String? serverVersion;
  final String? modifiedByDevice;
}
