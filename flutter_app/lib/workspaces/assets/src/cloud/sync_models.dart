class SyncClientContext {
  const SyncClientContext({
    required this.clientVersion,
    required this.deviceId,
    required this.schemaVersion,
    this.entityTypes = const {'asset.asset', 'asset.event'},
  });

  final String clientVersion;
  final String deviceId;
  final int schemaVersion;
  final Set<String> entityTypes;
}

class OutgoingSyncChange {
  const OutgoingSyncChange({
    required this.changeId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.baseServerVersion,
    required this.clientModifiedAt,
    this.entitySchemaVersion = 1,
    this.payload,
  });

  final String changeId;
  final String entityType;
  final String entityId;
  final String operation;
  final String baseServerVersion;
  final int entitySchemaVersion;
  final String clientModifiedAt;
  final Map<String, dynamic>? payload;
}

sealed class PushChangeResult {
  const PushChangeResult({
    required this.changeId,
    required this.entityType,
    required this.entityId,
  });
  final String changeId;
  final String entityType;
  final String entityId;
}

class PushAccepted extends PushChangeResult {
  const PushAccepted({
    required super.changeId,
    required super.entityType,
    required super.entityId,
    required this.serverVersion,
    required this.cursor,
    required this.serverModifiedAt,
    required this.duplicate,
  });

  final String serverVersion;
  final String cursor;
  final String serverModifiedAt;
  final bool duplicate;
}

class PushConflict extends PushChangeResult {
  const PushConflict({
    required super.changeId,
    required super.entityType,
    required super.entityId,
    required this.conflictId,
    required this.clientBaseServerVersion,
    required this.currentServerVersion,
    required this.serverDeleted,
    required this.reason,
    this.serverEntity,
  });

  final String conflictId;
  final String clientBaseServerVersion;
  final String currentServerVersion;
  final Map<String, dynamic>? serverEntity;
  final bool serverDeleted;
  final String reason;
}

class PushRejected extends PushChangeResult {
  const PushRejected({
    required super.changeId,
    required super.entityType,
    required super.entityId,
    required this.code,
    required this.message,
  });
  final String code;
  final String message;
}

class PushBatchResult {
  const PushBatchResult({
    required this.latestCursor,
    required this.results,
  });
  final String latestCursor;
  final List<PushChangeResult> results;
}

class PulledChange {
  const PulledChange({
    required this.cursor,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.serverVersion,
    required this.serverModifiedAt,
    this.payload,
  });

  final String cursor;
  final String entityType;
  final String entityId;
  final String operation;
  final String serverVersion;
  final String serverModifiedAt;
  final Map<String, dynamic>? payload;
}

class PullBatchResult {
  const PullBatchResult({
    required this.changes,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<PulledChange> changes;
  final String nextCursor;
  final bool hasMore;
}

class SnapshotItem {
  const SnapshotItem({
    required this.entityType,
    required this.entityId,
    required this.serverVersion,
    required this.payload,
  });
  final String entityType;
  final String entityId;
  final String serverVersion;
  final Map<String, dynamic> payload;
}

class SnapshotPageResult {
  const SnapshotPageResult({
    required this.snapshotId,
    required this.snapshotCursor,
    required this.items,
    required this.completed,
    this.nextPageToken,
  });
  final String snapshotId;
  final String snapshotCursor;
  final List<SnapshotItem> items;
  final String? nextPageToken;
  final bool completed;
}
