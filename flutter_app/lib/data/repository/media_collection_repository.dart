import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/collection/execution_file_metadata.dart';
import '../../domain/collection/execution_memo.dart';
import '../local/app_database.dart' as db;
import 'memo_repository.dart';

class PendingMediaResult {
  const PendingMediaResult({required this.memo, required this.upload});

  final ExecutionMemo memo;
  final PendingMediaUpload upload;
}

class MediaCollectionRepository {
  MediaCollectionRepository(this.database, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  final db.AppDatabase database;
  final Uuid _uuid;

  Future<PendingMediaResult> createPendingMedia({
    required String uploadId,
    required String userId,
    required String deviceId,
    required ExecutionMemoKind kind,
    required String localPath,
    required String originalName,
    required String mimeType,
    required int sizeBytes,
    required String sha256,
  }) async {
    if (!{
      ExecutionMemoKind.image,
      ExecutionMemoKind.audio,
      ExecutionMemoKind.file,
    }.contains(kind)) {
      throw ArgumentError.value(kind, 'kind', '媒体上传只支持图片、语音和文件');
    }

    final now = DateTime.now().toUtc().toIso8601String();
    final memo = ExecutionMemo(
      id: _uuid.v4(),
      userId: userId,
      kind: kind,
      title: originalName,
      content: originalName,
      status: ExecutionMemoStatus.inbox,
      createdAt: now,
      updatedAt: now,
      localVersion: 1,
      modifiedByDevice: deviceId,
    );
    final upload = PendingMediaUpload(
      id: uploadId,
      userId: userId,
      memoId: memo.id,
      kind: kind.wireValue,
      localPath: localPath,
      originalName: originalName,
      mimeType: mimeType,
      sizeBytes: sizeBytes,
      sha256: sha256,
      status: MediaUploadStatus.localOnly,
      attemptCount: 0,
      createdAt: now,
      updatedAt: now,
    );

    await database.transaction(() async {
      await database.into(database.memos).insert(MemoDatabaseMapper.toRow(memo));
      await database.into(database.mediaUploads).insert(
            db.MediaUploadsCompanion.insert(
              id: upload.id,
              userId: upload.userId,
              memoId: upload.memoId,
              kind: upload.kind,
              localPath: upload.localPath,
              originalName: upload.originalName,
              mimeType: upload.mimeType,
              sizeBytes: upload.sizeBytes,
              sha256: upload.sha256,
              status: upload.status.wireValue,
              createdAt: upload.createdAt,
              updatedAt: upload.updatedAt,
            ),
          );
      await database.into(database.syncOutbox).insert(
            db.SyncOutboxCompanion.insert(
              changeId: _uuid.v4(),
              userId: memo.userId,
              entityType: DriftMemoRepository.entityType,
              entityId: memo.id,
              operation: 'upsert',
              baseServerVersion: '0',
              clientModifiedAt: now,
              payloadJson: Value(jsonEncode(MemoWireMapper.toPayload(memo))),
              createdAt: now,
            ),
          );
    });

    return PendingMediaResult(memo: memo, upload: upload);
  }
}
