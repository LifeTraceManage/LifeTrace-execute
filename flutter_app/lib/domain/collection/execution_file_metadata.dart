enum ExecutionFileStorageState {
  localOnly('local_only'),
  pendingUpload('pending_upload'),
  serverStored('server_stored');

  const ExecutionFileStorageState(this.wireValue);
  final String wireValue;

  static ExecutionFileStorageState fromWire(String value) =>
      ExecutionFileStorageState.values.firstWhere(
        (state) => state.wireValue == value,
        orElse: () => ExecutionFileStorageState.localOnly,
      );
}

class ExecutionFileMetadata {
  const ExecutionFileMetadata({
    required this.id,
    required this.userId,
    required this.originalName,
    required this.mimeType,
    required this.sizeBytes,
    required this.sha256,
    required this.storageState,
    required this.createdAt,
    required this.updatedAt,
    required this.localVersion,
    this.createdByDevice,
    this.serverVersion,
    this.modifiedByDevice,
  });

  final String id;
  final String userId;
  final String originalName;
  final String mimeType;
  final int sizeBytes;
  final String sha256;
  final ExecutionFileStorageState storageState;
  final String? createdByDevice;
  final String createdAt;
  final String updatedAt;
  final int localVersion;
  final String? serverVersion;
  final String? modifiedByDevice;

  ExecutionFileMetadata copyWith({
    ExecutionFileStorageState? storageState,
    String? updatedAt,
    int? localVersion,
    String? serverVersion,
    String? modifiedByDevice,
  }) =>
      ExecutionFileMetadata(
        id: id,
        userId: userId,
        originalName: originalName,
        mimeType: mimeType,
        sizeBytes: sizeBytes,
        sha256: sha256,
        storageState: storageState ?? this.storageState,
        createdByDevice: createdByDevice,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        localVersion: localVersion ?? this.localVersion,
        serverVersion: serverVersion ?? this.serverVersion,
        modifiedByDevice: modifiedByDevice ?? this.modifiedByDevice,
      );
}

enum MediaUploadStatus {
  localOnly('local_only'),
  pendingUpload('pending_upload'),
  uploading('uploading'),
  failed('failed'),
  serverStored('server_stored');

  const MediaUploadStatus(this.wireValue);
  final String wireValue;

  static MediaUploadStatus fromWire(String value) =>
      MediaUploadStatus.values.firstWhere(
        (status) => status.wireValue == value,
        orElse: () => MediaUploadStatus.localOnly,
      );
}

class PendingMediaUpload {
  const PendingMediaUpload({
    required this.id,
    required this.userId,
    required this.memoId,
    required this.kind,
    required this.localPath,
    required this.originalName,
    required this.mimeType,
    required this.sizeBytes,
    required this.sha256,
    required this.status,
    required this.attemptCount,
    required this.createdAt,
    required this.updatedAt,
    this.serverFileId,
    this.errorMessage,
  });

  final String id;
  final String userId;
  final String memoId;
  final String kind;
  final String localPath;
  final String originalName;
  final String mimeType;
  final int sizeBytes;
  final String sha256;
  final MediaUploadStatus status;
  final int attemptCount;
  final String? serverFileId;
  final String? errorMessage;
  final String createdAt;
  final String updatedAt;
}
