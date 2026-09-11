import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repository/collection_workflow_repository.dart';
import '../../data/repository/memo_repository.dart';
import '../../data/sync/collection_conflict_resolver.dart';
import '../../domain/collection/execution_memo.dart';
import '../../domain/task/execution_task.dart';
import '../tasks/task_providers.dart';
import 'media_providers.dart';

final memoRepositoryProvider = Provider<MemoRepository>((ref) {
  if (kIsWeb) return PreviewMemoRepository();
  final database = ref.watch(appDatabaseProvider);
  if (database == null) {
    throw StateError('Android production database is unavailable');
  }
  return DriftMemoRepository(database);
});

final memoListProvider = StreamProvider<List<ExecutionMemo>>((ref) async* {
  final repository = ref.watch(memoRepositoryProvider);
  final userId = await ref.watch(currentUserIdProvider.future);
  if (userId == null) {
    yield const <ExecutionMemo>[];
    return;
  }
  yield* repository.watchMemos(userId);
});

final inboxMemoListProvider = Provider<AsyncValue<List<ExecutionMemo>>>((ref) {
  return ref.watch(memoListProvider).whenData(
        (items) => items.where((memo) => memo.isInbox).toList(growable: false),
      );
});

final collectionWorkflowRepositoryProvider =
    Provider<CollectionWorkflowRepository?>((ref) {
  if (kIsWeb) return null;
  final database = ref.watch(appDatabaseProvider);
  return database == null ? null : CollectionWorkflowRepository(database);
});

final collectionConflictResolverProvider =
    Provider<CollectionConflictResolver?>((ref) {
  if (kIsWeb) return null;
  final database = ref.watch(appDatabaseProvider);
  return database == null ? null : CollectionConflictResolver(database);
});

class CollectionConflictUi {
  const CollectionConflictUi({
    required this.conflictId,
    required this.entityId,
    required this.entityType,
    required this.localTitle,
    required this.serverTitle,
    required this.reason,
  });

  final String conflictId;
  final String entityId;
  final String entityType;
  final String? localTitle;
  final String? serverTitle;
  final String reason;
}

final collectionConflictsProvider =
    StreamProvider<List<CollectionConflictUi>>((ref) async* {
  if (kIsWeb) {
    yield const <CollectionConflictUi>[];
    return;
  }
  final database = ref.watch(appDatabaseProvider);
  final userId = await ref.watch(currentUserIdProvider.future);
  if (database == null || userId == null) {
    yield const <CollectionConflictUi>[];
    return;
  }

  final query = database.select(database.syncConflicts)
    ..where(
      (table) =>
          table.userId.equals(userId) &
          table.entityType.isIn(
            const ['execution.memo', 'file.metadata', 'entity.link'],
          ) &
          table.resolved.equals(false),
    )
    ..orderBy([(table) => OrderingTerm.desc(table.createdAt)]);
  yield* query.watch().map(
        (rows) => rows
            .map(
              (row) => CollectionConflictUi(
                conflictId: row.id,
                entityId: row.entityId,
                entityType: row.entityType,
                localTitle: _payloadTitle(row.localPayloadJson),
                serverTitle: row.serverDeleted
                    ? null
                    : _payloadTitle(row.serverPayloadJson),
                reason: row.reason,
              ),
            )
            .toList(growable: false),
      );
});

final collectionCommandsProvider =
    Provider<CollectionCommands>(CollectionCommands.new);

class CollectionCommands {
  CollectionCommands(this.ref);

  final Ref ref;

  Future<ExecutionMemo> create({
    required ExecutionMemoKind kind,
    required String content,
    String? title,
    String? sourceUrl,
    bool important = false,
  }) async {
    final memo = await ref.read(memoRepositoryProvider).createMemo(
          userId: await _requireUserId(),
          deviceId: await ref.read(deviceIdProvider.future),
          kind: kind,
          content: content,
          title: title,
          sourceUrl: sourceUrl,
          important: important,
        );
    _scheduleSync();
    return memo;
  }

  Future<ExecutionMemo> update({
    required ExecutionMemo memo,
    String? title,
    String? content,
    String? sourceUrl,
    bool? important,
    bool clearTitle = false,
    bool clearSourceUrl = false,
  }) async {
    final updated = await ref.read(memoRepositoryProvider).updateMemo(
          memo: memo,
          deviceId: await ref.read(deviceIdProvider.future),
          title: title,
          content: content,
          sourceUrl: sourceUrl,
          important: important,
          clearTitle: clearTitle,
          clearSourceUrl: clearSourceUrl,
        );
    _scheduleSync();
    return updated;
  }

  Future<ExecutionMemo> toggleImportant(ExecutionMemo memo) =>
      update(memo: memo, important: !memo.important);

  Future<ExecutionMemo> archive(ExecutionMemo memo) async {
    final updated = await ref.read(memoRepositoryProvider).updateMemo(
          memo: memo,
          deviceId: await ref.read(deviceIdProvider.future),
          status: ExecutionMemoStatus.archived,
        );
    _scheduleSync();
    return updated;
  }

  Future<void> delete(ExecutionMemo memo) async {
    if (!kIsWeb) {
      await ref
          .read(mediaUploadRepositoryProvider)
          ?.removeForMemo(memo.userId, memo.id);
    }
    await ref.read(memoRepositoryProvider).deleteMemo(
          userId: memo.userId,
          memoId: memo.id,
        );
    _scheduleSync();
  }

  Future<ExecutionTask> convertToTask(ExecutionMemo memo) async {
    final deviceId = await ref.read(deviceIdProvider.future);
    if (kIsWeb) {
      final task = await ref.read(taskRepositoryProvider).createTask(
            userId: memo.userId,
            deviceId: deviceId,
            title: _memoTaskTitle(memo),
            description: memo.content,
          );
      await ref.read(memoRepositoryProvider).updateMemo(
            memo: memo,
            deviceId: deviceId,
            status: ExecutionMemoStatus.archived,
          );
      return task;
    }
    final workflow = ref.read(collectionWorkflowRepositoryProvider);
    if (workflow == null) throw StateError('Collection workflow unavailable');
    final result = await workflow.convertMemoToTask(
      memo: memo,
      deviceId: deviceId,
    );
    _scheduleSync();
    return result.task;
  }

  Future<void> organizeToProject(
    ExecutionMemo memo,
    String projectId,
  ) async {
    if (kIsWeb) {
      await archive(memo);
      return;
    }
    final workflow = ref.read(collectionWorkflowRepositoryProvider);
    if (workflow == null) throw StateError('Collection workflow unavailable');
    await workflow.organizeMemoToProject(
      memo: memo,
      projectId: projectId,
      deviceId: await ref.read(deviceIdProvider.future),
    );
    _scheduleSync();
  }

  Future<void> keepServer(String conflictId) async {
    final resolver = ref.read(collectionConflictResolverProvider);
    if (resolver == null) return;
    await resolver.keepServer(conflictId);
    await ref.read(taskSyncControllerProvider.notifier).syncNow(silent: true);
  }

  Future<void> keepLocal(String conflictId) async {
    final resolver = ref.read(collectionConflictResolverProvider);
    if (resolver == null) return;
    await resolver.keepLocal(
      conflictId: conflictId,
      deviceId: await ref.read(deviceIdProvider.future),
    );
    await ref.read(taskSyncControllerProvider.notifier).syncNow(silent: true);
  }

  Future<String> _requireUserId() async {
    final userId = await ref.read(currentUserIdProvider.future);
    if (userId == null) throw StateError('请先连接 LifeTrace Cloud');
    return userId;
  }

  void _scheduleSync() {
    if (kIsWeb) return;
    unawaited(
      ref.read(taskSyncControllerProvider.notifier).syncNow(silent: true),
    );
  }

  static String _memoTaskTitle(ExecutionMemo memo) {
    final title = memo.title?.trim();
    if (title != null && title.isNotEmpty) return title;
    final text = memo.content.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.length <= 60 ? text : '${text.substring(0, 60)}…';
  }
}

String? _payloadTitle(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final value = jsonDecode(raw);
    if (value is! Map) return null;
    final title = value['title']?.toString().trim();
    if (title != null && title.isNotEmpty) return title;
    final content = value['content']?.toString().trim();
    return content == null || content.isEmpty ? null : content;
  } catch (_) {
    return null;
  }
}
