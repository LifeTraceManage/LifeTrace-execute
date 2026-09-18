import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../core/cloud/cloud_session_manager.dart';
import '../../core/cloud/lifetrace_files_client.dart';
import '../../core/files/local_file_access.dart';
import '../../domain/collection/entity_link.dart';
import '../../domain/collection/execution_file_metadata.dart';
import '../local/app_database.dart' as db;
import '../repository/entity_link_repository.dart';
import '../repository/file_metadata_repository.dart';
import '../repository/media_upload_repository.dart';
import '../repository/memo_repository.dart';

typedef MediaDeviceIdLoader = Future<String> Function();

class MediaUploadSummary {
  const MediaUploadSummary({
    required this.completed,
    required this.failed,
  });

  final int completed;
  final int failed;
}

class MediaUploadCoordinator {
  MediaUploadCoordinator({
    required this.database,
    CloudSessionAccess? sessionManager,
    FilesClient? filesClient,
    required MediaDeviceIdLoader deviceIdLoader,
    Uuid? uuid,
  })  : _sessionManager = sessionManager ?? CloudSessionManager(),
        _filesClient = filesClient ?? LifeTraceFilesClient(),
        _deviceIdLoader = deviceIdLoader,
        _uuid = uuid ?? const Uuid(),
        _uploads = MediaUploadRepository(database);

  final db.AppDatabase database;
  final CloudSessionAccess _sessionManager;
  final FilesClient _filesClient;
  final MediaDeviceIdLoader _deviceIdLoader;
  final Uuid _uuid;
  final MediaUploadRepository _uploads;

  Future<MediaUploadSummary>? _active;

  Future<MediaUploadSummary> processPending() {
    final current = _active;
    if (current != null) return current;

    late final Future<MediaUploadSummary> tracked;
    tracked = _processInternal().whenComplete(() {
      if (identical(_active, tracked)) _active = null;
    });
    _active = tracked;
    return tracked;
  }

  Future<MediaUploadSummary> retryOne(String uploadId) {
    return _sessionManager.authorized((session) async {
      final upload = await _uploads.findById(uploadId);
      if (upload == null || upload.userId != session.userId) {
        throw StateError('上传任务不存在');
      }
      try {
        await _uploadOne(
          sessionBaseUrl: session.baseUrl,
          accessToken: session.accessToken,
          upload: upload,
          deviceId: await _deviceIdLoader(),
        );
        return const MediaUploadSummary(completed: 1, failed: 0);
      } catch (_) {
        return const MediaUploadSummary(completed: 0, failed: 1);
      }
    });
  }

  Future<MediaUploadSummary> _processInternal() {
    return _sessionManager.authorized((session) async {
      final pending = await _uploads.pendingForUser(session.userId);
      if (pending.isEmpty) {
        return const MediaUploadSummary(completed: 0, failed: 0);
      }

      final deviceId = await _deviceIdLoader();
      var completed = 0;
      var failed = 0;
      for (final upload in pending) {
        try {
          await _uploadOne(
            sessionBaseUrl: session.baseUrl,
            accessToken: session.accessToken,
            upload: upload,
            deviceId: deviceId,
          );
          completed++;
        } catch (_) {
          failed++;
        }
      }
      return MediaUploadSummary(completed: completed, failed: failed);
    });
  }

  Future<void> _uploadOne({
    required String sessionBaseUrl,
    required String accessToken,
    required PendingMediaUpload upload,
    required String deviceId,
  }) async {
    final start = DateTime.now().toUtc().toIso8601String();
    await (database.update(database.mediaUploads)
          ..where((table) => table.id.equals(upload.id)))
        .write(
      db.MediaUploadsCompanion(
        status: const Value('uploading'),
        attemptCount: Value(upload.attemptCount + 1),
        errorMessage: const Value(null),
        updatedAt: Value(start),
      ),
    );

    String? serverFileId = upload.serverFileId;
    try {
      final prepared = await _filesClient.prepare(
        baseUrl: sessionBaseUrl,
        accessToken: accessToken,
        originalName: upload.originalName,
        mimeType: upload.mimeType,
        sizeBytes: upload.sizeBytes,
        sha256: upload.sha256,
        entityType: DriftMemoRepository.entityType,
        entityId: upload.memoId,
      );
      serverFileId = prepared.file.id;
      await (database.update(database.mediaUploads)
            ..where((table) => table.id.equals(upload.id)))
          .write(
        db.MediaUploadsCompanion(
          status: const Value('pending_upload'),
          serverFileId: Value(serverFileId),
          updatedAt: Value(DateTime.now().toUtc().toIso8601String()),
        ),
      );

      var available = prepared.file;
      if (available.status != 'available') {
        final transfer = prepared.upload;
        if (transfer == null) {
          throw StateError('Cloud 未返回可用上传地址');
        }
        await _filesClient.upload(
          transfer: transfer,
          bytes: openLocalFileStream(upload.localPath),
          sizeBytes: upload.sizeBytes,
        );
        available = await _filesClient.complete(
          baseUrl: sessionBaseUrl,
          accessToken: accessToken,
          fileId: prepared.file.id,
        );
      }
      if (available.status != 'available') {
        throw StateError('Cloud 文件未进入 available 状态');
      }

      await _finalizeStored(
        upload: upload,
        serverFileId: available.id,
        deviceId: deviceId,
      );
      await deleteLocalFile(upload.localPath);
    } catch (error) {
      final now = DateTime.now().toUtc().toIso8601String();
      await (database.update(database.mediaUploads)
            ..where((table) => table.id.equals(upload.id)))
          .write(
        db.MediaUploadsCompanion(
          status: const Value('failed'),
          serverFileId: Value(serverFileId),
          errorMessage: Value(error.toString()),
          updatedAt: Value(now),
        ),
      );
      if (serverFileId != null) {
        try {
          await _filesClient.markFailed(
            baseUrl: sessionBaseUrl,
            accessToken: accessToken,
            fileId: serverFileId,
            reason: error.toString(),
          );
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<void> _finalizeStored({
    required PendingMediaUpload upload,
    required String serverFileId,
    required String deviceId,
  }) async {
    final nowValue = DateTime.now().toUtc();
    final now = nowValue.toIso8601String();
    final linkTime =
        nowValue.add(const Duration(milliseconds: 1)).toIso8601String();

    final file = ExecutionFileMetadata(
      id: serverFileId,
      userId: upload.userId,
      originalName: upload.originalName,
      mimeType: upload.mimeType,
      sizeBytes: upload.sizeBytes,
      sha256: upload.sha256,
      storageState: ExecutionFileStorageState.serverStored,
      createdByDevice: deviceId,
      createdAt: now,
      updatedAt: now,
      localVersion: 1,
      modifiedByDevice: deviceId,
    );
    final link = ExecutionEntityLink(
      id: _uuid.v4(),
      userId: upload.userId,
      sourceType: DriftMemoRepository.entityType,
      sourceId: upload.memoId,
      targetType: DriftFileMetadataRepository.entityType,
      targetId: serverFileId,
      relationType: 'attachment',
      metadata: {'kind': upload.kind},
      createdAt: linkTime,
      updatedAt: linkTime,
      localVersion: 1,
      modifiedByDevice: deviceId,
    );

    await database.transaction(() async {
      await database
          .into(database.fileRecords)
          .insertOnConflictUpdate(FileMetadataDatabaseMapper.toRow(file));
      await database
          .into(database.entityLinks)
          .insert(EntityLinkDatabaseMapper.toRow(link));

      await database.into(database.syncOutbox).insert(
            db.SyncOutboxCompanion.insert(
              changeId: _uuid.v4(),
              userId: file.userId,
              entityType: DriftFileMetadataRepository.entityType,
              entityId: file.id,
              operation: 'upsert',
              baseServerVersion: '0',
              clientModifiedAt: now,
              payloadJson: Value(
                jsonEncode(FileMetadataWireMapper.toPayload(file)),
              ),
              createdAt: now,
            ),
          );

      await database.into(database.syncOutbox).insert(
            db.SyncOutboxCompanion.insert(
              changeId: _uuid.v4(),
              userId: link.userId,
              entityType: DriftEntityLinkRepository.entityType,
              entityId: link.id,
              operation: 'upsert',
              baseServerVersion: '0',
              clientModifiedAt: linkTime,
              payloadJson: Value(
                jsonEncode(EntityLinkWireMapper.toPayload(link)),
              ),
              dependenciesJson: Value(
                jsonEncode([
                  {
                    'entityType': DriftMemoRepository.entityType,
                    'entityId': upload.memoId,
                  },
                  {
                    'entityType': DriftFileMetadataRepository.entityType,
                    'entityId': file.id,
                  },
                ]),
              ),
              createdAt: linkTime,
            ),
          );

      await (database.update(database.mediaUploads)
            ..where((table) => table.id.equals(upload.id)))
          .write(
        db.MediaUploadsCompanion(
          status: const Value('server_stored'),
          serverFileId: Value(serverFileId),
          errorMessage: const Value(null),
          updatedAt: Value(now),
        ),
      );
    });
  }
}
