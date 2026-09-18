import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/data/local/app_database.dart';
import 'package:lifetrace_execute/data/repository/memo_repository.dart';
import 'package:lifetrace_execute/domain/collection/execution_memo.dart';

void main() {
  late AppDatabase database;
  late DriftMemoRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = DriftMemoRepository(database);
  });

  tearDown(() async => database.close());

  test('memo CRUD persists locally and writes execution.memo outbox', () async {
    final created = await repository.createMemo(
      userId: 'user-1',
      deviceId: 'device-1',
      kind: ExecutionMemoKind.idea,
      title: '  Idea  ',
      content: '  Build a real inbox  ',
      important: true,
    );

    expect(created.title, 'Idea');
    expect(created.content, 'Build a real inbox');
    expect(created.status, ExecutionMemoStatus.inbox);
    expect(await database.select(database.memos).get(), hasLength(1));

    var outbox = await database.select(database.syncOutbox).get();
    expect(outbox, hasLength(1));
    expect(outbox.single.entityType, DriftMemoRepository.entityType);
    expect(outbox.single.operation, 'upsert');

    final archived = await repository.updateMemo(
      memo: created,
      deviceId: 'device-1',
      status: ExecutionMemoStatus.archived,
    );
    expect(archived.localVersion, 2);
    expect(archived.status, ExecutionMemoStatus.archived);

    final secondPayload =
        jsonDecode((await database.select(database.syncOutbox).get()).last.payloadJson!);
    expect(secondPayload['status'], 'archived');

    await repository.deleteMemo(userId: 'user-1', memoId: created.id);
    expect(await database.select(database.memos).get(), isEmpty);
    outbox = await database.select(database.syncOutbox).get();
    expect(outbox.last.operation, 'delete');
  });

  test('link memo requires http or https source URL', () async {
    expect(
      () => repository.createMemo(
        userId: 'user-1',
        deviceId: 'device-1',
        kind: ExecutionMemoKind.link,
        content: 'invalid',
        sourceUrl: 'ftp://example.com/file',
      ),
      throwsArgumentError,
    );

    final valid = await repository.createMemo(
      userId: 'user-1',
      deviceId: 'device-1',
      kind: ExecutionMemoKind.link,
      content: 'paper',
      sourceUrl: 'https://example.com/paper',
    );
    expect(valid.sourceUrl, 'https://example.com/paper');
  });
}
