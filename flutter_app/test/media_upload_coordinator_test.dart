import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/core/cloud/cloud_session_manager.dart';
import 'package:lifetrace_execute/core/cloud/lifetrace_files_client.dart';
import 'package:lifetrace_execute/core/cloud/secure_session_store.dart';
import 'package:lifetrace_execute/data/local/app_database.dart';
import 'package:lifetrace_execute/data/repository/entity_link_repository.dart';
import 'package:lifetrace_execute/data/repository/file_metadata_repository.dart';
import 'package:lifetrace_execute/data/repository/media_collection_repository.dart';
import 'package:lifetrace_execute/data/sync/media_upload_coordinator.dart';
import 'package:lifetrace_execute/domain/collection/execution_memo.dart';

void main() {
  late AppDatabase database;
  late Directory tempDirectory;
  late File localFile;
  late MediaCollectionRepository collection;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    tempDirectory = await Directory.systemTemp.createTemp('lifetrace-media-test');
    localFile = File('${tempDirectory.path}/diagram.png');
    await localFile.writeAsBytes(List<int>.generate(128, (index) => index));
    collection = MediaCollectionRepository(database);
  });

  tearDown(() async {
    await database.close();
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  test('successful upload creates file metadata and attachment link', () async {
    final pending = await collection.createPendingMedia(
      uploadId: 'upload-1',
      userId: 'user-1',
      deviceId: 'device-1',
      kind: ExecutionMemoKind.image,
      localPath: localFile.path,
      originalName: 'diagram.png',
      mimeType: 'image/png',
      sizeBytes: await localFile.length(),
      sha256: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
    );
    final files = _FakeFilesClient();

    final summary = await MediaUploadCoordinator(
      database: database,
      sessionManager: const _FakeSessionAccess(),
      filesClient: files,
      deviceIdLoader: () async => 'device-1',
    ).processPending();

    expect(summary.completed, 1);
    expect(summary.failed, 0);
    expect(files.uploadedBytes, 128);

    final queue = (await database.select(database.mediaUploads).get()).single;
    expect(queue.status, 'server_stored');
    expect(queue.serverFileId, 'file-1');
    expect(await localFile.exists(), isFalse);

    final metadata = (await database.select(database.fileRecords).get()).single;
    expect(metadata.id, 'file-1');
    expect(metadata.storageState, 'server_stored');

    final link = (await database.select(database.entityLinks).get()).single;
    expect(link.sourceId, pending.memo.id);
    expect(link.targetId, 'file-1');
    expect(link.relationType, 'attachment');

    final outbox = await database.select(database.syncOutbox).get();
    final fileChange = outbox.singleWhere(
      (row) => row.entityType == DriftFileMetadataRepository.entityType,
    );
    final linkChange = outbox.singleWhere(
      (row) => row.entityType == DriftEntityLinkRepository.entityType,
    );
    expect(fileChange.operation, 'upsert');
    expect(linkChange.dependenciesJson, contains('file.metadata'));
    expect(linkChange.dependenciesJson, contains(pending.memo.id));
  });

  test('failed upload stays retryable and retry can complete', () async {
    await collection.createPendingMedia(
      uploadId: 'upload-2',
      userId: 'user-1',
      deviceId: 'device-1',
      kind: ExecutionMemoKind.file,
      localPath: localFile.path,
      originalName: 'diagram.png',
      mimeType: 'image/png',
      sizeBytes: await localFile.length(),
      sha256: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
    );
    final files = _FakeFilesClient(failUpload: true);
    final coordinator = MediaUploadCoordinator(
      database: database,
      sessionManager: const _FakeSessionAccess(),
      filesClient: files,
      deviceIdLoader: () async => 'device-1',
    );

    final first = await coordinator.processPending();
    expect(first.failed, 1);
    var queue = (await database.select(database.mediaUploads).get()).single;
    expect(queue.status, 'failed');
    expect(queue.errorMessage, isNotEmpty);
    expect(await localFile.exists(), isTrue);

    files.failUpload = false;
    final retry = await coordinator.retryOne('upload-2');
    expect(retry.completed, 1);
    queue = (await database.select(database.mediaUploads).get()).single;
    expect(queue.status, 'server_stored');
    expect(await localFile.exists(), isFalse);
  });
}

class _FakeSessionAccess implements CloudSessionAccess {
  const _FakeSessionAccess();

  static const session = StoredCloudSession(
    baseUrl: 'https://cloud.example.com',
    accessToken: 'token',
    accessTokenExpiresAtEpochSeconds: 9999999999,
    userId: 'user-1',
    email: 'user@example.com',
    sessionId: 'session-1',
    scopes: ['files:read', 'files:write', 'sync:read', 'sync:write'],
    protocolVersion: 1,
    schemaVersion: 1,
  );

  @override
  Future<StoredCloudSession?> currentSession() async => session;

  @override
  Future<T> authorized<T>(
    Future<T> Function(StoredCloudSession session) block,
  ) =>
      block(session);
}

class _FakeFilesClient implements FilesClient {
  _FakeFilesClient({this.failUpload = false});

  bool failUpload;
  int uploadedBytes = 0;

  @override
  Future<PreparedCloudFile> prepare({
    required String baseUrl,
    required String accessToken,
    required String originalName,
    required String mimeType,
    required int sizeBytes,
    required String sha256,
    required String entityType,
    required String entityId,
  }) async {
    return PreparedCloudFile(
      file: CloudFileObject(
        id: 'file-1',
        domain: 'notes_attachments',
        originalName: originalName,
        mimeType: mimeType,
        sizeBytes: sizeBytes,
        sha256: sha256,
        status: 'pending',
        entityType: entityType,
        entityId: entityId,
      ),
      deduplicated: false,
      upload: const SignedFileTransfer(
        url: 'https://storage.example.com/upload',
        requiredHeaders: {'x-amz-checksum-sha256': 'checksum'},
        expiresSeconds: 300,
      ),
    );
  }

  @override
  Future<void> upload({
    required SignedFileTransfer transfer,
    required Stream<List<int>> bytes,
    required int sizeBytes,
  }) async {
    if (failUpload) throw StateError('simulated upload failure');
    uploadedBytes = await bytes.fold<int>(
      0,
      (total, chunk) => total + chunk.length,
    );
  }

  @override
  Future<CloudFileObject> complete({
    required String baseUrl,
    required String accessToken,
    required String fileId,
  }) async {
    return const CloudFileObject(
      id: 'file-1',
      domain: 'notes_attachments',
      originalName: 'diagram.png',
      mimeType: 'image/png',
      sizeBytes: 128,
      sha256: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      status: 'available',
      entityType: 'execution.memo',
      entityId: 'memo-1',
    );
  }

  @override
  Future<void> markFailed({
    required String baseUrl,
    required String accessToken,
    required String fileId,
    required String reason,
  }) async {}
}
