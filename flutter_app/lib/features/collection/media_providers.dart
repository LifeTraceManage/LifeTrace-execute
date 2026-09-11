import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/files/local_file_access.dart';
import '../../data/repository/media_collection_repository.dart';
import '../../data/repository/media_upload_repository.dart';
import '../../data/sync/media_upload_coordinator.dart';
import '../../domain/collection/execution_file_metadata.dart';
import '../../domain/collection/execution_memo.dart';
import '../tasks/task_providers.dart';

final mediaUploadRepositoryProvider = Provider<MediaUploadRepository?>((ref) {
  if (kIsWeb) return null;
  final database = ref.watch(appDatabaseProvider);
  return database == null ? null : MediaUploadRepository(database);
});

final mediaCollectionRepositoryProvider =
    Provider<MediaCollectionRepository?>((ref) {
  if (kIsWeb) return null;
  final database = ref.watch(appDatabaseProvider);
  return database == null ? null : MediaCollectionRepository(database);
});

final mediaUploadListProvider =
    StreamProvider<List<PendingMediaUpload>>((ref) async* {
  if (kIsWeb) {
    yield const <PendingMediaUpload>[];
    return;
  }
  final repository = ref.watch(mediaUploadRepositoryProvider);
  final userId = await ref.watch(currentUserIdProvider.future);
  if (repository == null || userId == null) {
    yield const <PendingMediaUpload>[];
    return;
  }
  yield* repository.watchUploads(userId);
});

final mediaUploadCoordinatorProvider = Provider<MediaUploadCoordinator?>((ref) {
  if (kIsWeb) return null;
  final database = ref.watch(appDatabaseProvider);
  if (database == null) return null;
  return MediaUploadCoordinator(
    database: database,
    sessionManager: ref.watch(cloudSessionManagerProvider),
    deviceIdLoader: () => ref.read(deviceIdProvider.future),
  );
});

class MediaUploadController extends AsyncNotifier<MediaUploadSummary?> {
  @override
  FutureOr<MediaUploadSummary?> build() => null;

  Future<MediaUploadSummary?> processPending({bool silent = false}) async {
    final coordinator = ref.read(mediaUploadCoordinatorProvider);
    if (coordinator == null) return null;

    if (silent) {
      try {
        final summary = await coordinator.processPending();
        if (summary.completed > 0) {
          await ref
              .read(taskSyncControllerProvider.notifier)
              .syncNow(silent: true);
        }
        return summary;
      } catch (_) {
        return null;
      }
    }

    state = const AsyncLoading();
    final next = await AsyncValue.guard(coordinator.processPending);
    state = next;
    final summary = next.valueOrNull;
    if (summary != null && summary.completed > 0) {
      await ref.read(taskSyncControllerProvider.notifier).syncNow(silent: true);
    }
    return summary;
  }

  Future<MediaUploadSummary?> retryOne(String uploadId) async {
    final coordinator = ref.read(mediaUploadCoordinatorProvider);
    if (coordinator == null) return null;

    state = const AsyncLoading();
    final next = await AsyncValue.guard(() => coordinator.retryOne(uploadId));
    state = next;
    final summary = next.valueOrNull;
    if (summary != null && summary.completed > 0) {
      await ref.read(taskSyncControllerProvider.notifier).syncNow(silent: true);
    }
    return summary;
  }
}

final mediaUploadControllerProvider =
    AsyncNotifierProvider<MediaUploadController, MediaUploadSummary?>(
  MediaUploadController.new,
);

final mediaCommandsProvider = Provider<MediaCommands>(MediaCommands.new);

class MediaCommands {
  MediaCommands(this.ref);

  final Ref ref;
  final Uuid _uuid = const Uuid();

  Future<ExecutionMemo?> pickAndQueue(ExecutionMemoKind kind) async {
    if (kIsWeb) {
      throw StateError('Web preview 不执行设备文件上传');
    }
    if (!{
      ExecutionMemoKind.image,
      ExecutionMemoKind.audio,
      ExecutionMemoKind.file,
    }.contains(kind)) {
      throw ArgumentError.value(kind, 'kind', '不是媒体类型');
    }

    final result = await FilePicker.platform.pickFiles(
      type: switch (kind) {
        ExecutionMemoKind.image => FileType.image,
        ExecutionMemoKind.audio => FileType.audio,
        _ => FileType.any,
      },
      allowMultiple: false,
      withData: false,
      withReadStream: false,
    );
    if (result == null || result.files.isEmpty) return null;

    final selected = result.files.single;
    final sourcePath = selected.path;
    if (sourcePath == null || sourcePath.isEmpty) {
      throw StateError('无法访问所选文件的本地路径');
    }

    final mimeType = lookupMimeType(selected.name);
    if (mimeType == null || !_allowedNotesMime(mimeType)) {
      throw StateError('该文件类型不受 LifeTrace 附件服务支持');
    }
    if (kind == ExecutionMemoKind.image && !mimeType.startsWith('image/')) {
      throw StateError('请选择图片文件');
    }
    if (kind == ExecutionMemoKind.audio && !mimeType.startsWith('audio/')) {
      throw StateError('请选择音频文件');
    }

    final uploadId = _uuid.v4();
    final support = await getApplicationSupportDirectory();
    final managedDirectory = p.join(support.path, 'media_uploads');
    final localPath = await persistPickedFile(
      sourcePath: sourcePath,
      directoryPath: managedDirectory,
      uploadId: uploadId,
      originalName: selected.name,
    );

    try {
      final sizeBytes = await localFileLength(localPath);
      if (sizeBytes <= 0) throw StateError('不能上传空文件');
      final sha256 = await localFileSha256(localPath);
      final repository = ref.read(mediaCollectionRepositoryProvider);
      if (repository == null) {
        throw StateError('媒体本地存储不可用');
      }
      final userId = await ref.read(currentUserIdProvider.future);
      if (userId == null) throw StateError('请先连接 LifeTrace Cloud');

      final result = await repository.createPendingMedia(
        uploadId: uploadId,
        userId: userId,
        deviceId: await ref.read(deviceIdProvider.future),
        kind: kind,
        localPath: localPath,
        originalName: selected.name,
        mimeType: mimeType,
        sizeBytes: sizeBytes,
        sha256: sha256,
      );

      unawaited(
        ref.read(taskSyncControllerProvider.notifier).syncNow(silent: true),
      );
      unawaited(
        ref
            .read(mediaUploadControllerProvider.notifier)
            .processPending(silent: true),
      );
      return result.memo;
    } catch (_) {
      await deleteLocalFile(localPath);
      rethrow;
    }
  }

  static bool _allowedNotesMime(String value) =>
      value.startsWith('image/') ||
      value.startsWith('audio/') ||
      value.startsWith('video/') ||
      const {
        'application/pdf',
        'text/plain',
        'text/markdown',
        'application/zip',
      }.contains(value);
}
