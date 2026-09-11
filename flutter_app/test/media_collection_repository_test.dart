import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/data/local/app_database.dart';
import 'package:lifetrace_execute/data/repository/media_collection_repository.dart';
import 'package:lifetrace_execute/data/repository/memo_repository.dart';
import 'package:lifetrace_execute/domain/collection/execution_memo.dart';

void main() {
  late AppDatabase database;
  late MediaCollectionRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = MediaCollectionRepository(database);
  });

  tearDown(() async => database.close());

  test('pending media persists memo, queue and memo outbox atomically', () async {
    final result = await repository.createPendingMedia(
      uploadId: 'upload-1',
      userId: 'user-1',
      deviceId: 'device-1',
      kind: ExecutionMemoKind.image,
      localPath: '/tmp/diagram.png',
      originalName: 'diagram.png',
      mimeType: 'image/png',
      sizeBytes: 1024,
      sha256: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
    );

    expect(result.memo.kind, ExecutionMemoKind.image);
    expect(result.upload.memoId, result.memo.id);
    expect(await database.select(database.memos).get(), hasLength(1));
    expect(await database.select(database.mediaUploads).get(), hasLength(1));

    final outbox = await database.select(database.syncOutbox).get();
    expect(outbox, hasLength(1));
    expect(outbox.single.entityType, DriftMemoRepository.entityType);
    expect(outbox.single.entityId, result.memo.id);
  });
}
