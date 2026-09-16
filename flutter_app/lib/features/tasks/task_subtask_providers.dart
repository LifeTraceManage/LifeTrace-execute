import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/background/background_sync.dart';
import '../../data/repository/entity_link_repository.dart';
import '../../data/repository/task_repository.dart';
import '../../domain/collection/entity_link.dart';
import '../../domain/task/execution_task.dart';
import 'task_providers.dart';

const taskSubtaskRelationType = 'subtask';

class TaskSubtaskUi {
  const TaskSubtaskUi({
    required this.link,
    required this.task,
  });

  final ExecutionEntityLink link;
  final ExecutionTask task;
}

final taskEntityLinkRepositoryProvider =
    Provider<DriftEntityLinkRepository?>((ref) {
  if (kIsWeb) return null;
  final database = ref.watch(appDatabaseProvider);
  return database == null ? null : DriftEntityLinkRepository(database);
});

final taskSubtaskLinksProvider = StreamProvider.family<
    List<ExecutionEntityLink>, String>((ref, parentTaskId) async* {
  if (kIsWeb) {
    yield const <ExecutionEntityLink>[];
    return;
  }
  final repository = ref.watch(taskEntityLinkRepositoryProvider);
  final userId = await ref.watch(currentUserIdProvider.future);
  if (repository == null || userId == null) {
    yield const <ExecutionEntityLink>[];
    return;
  }
  yield* repository
      .watchLinksForEntity(
        userId: userId,
        entityType: DriftTaskRepository.entityType,
        entityId: parentTaskId,
      )
      .map(
        (links) => links
            .where(
              (link) =>
                  link.sourceType == DriftTaskRepository.entityType &&
                  link.sourceId == parentTaskId &&
                  link.targetType == DriftTaskRepository.entityType &&
                  link.relationType == taskSubtaskRelationType,
            )
            .toList(growable: false),
      );
});

final taskSubtasksProvider = Provider.family<
    AsyncValue<List<TaskSubtaskUi>>, String>((ref, parentTaskId) {
  final links = ref.watch(taskSubtaskLinksProvider(parentTaskId));
  final tasks = ref.watch(taskListProvider);

  return links.when(
    loading: () => const AsyncLoading(),
    error: (error, stackTrace) =>
        AsyncError<List<TaskSubtaskUi>>(error, stackTrace),
    data: (items) => tasks.when(
      loading: () => const AsyncLoading(),
      error: (error, stackTrace) =>
          AsyncError<List<TaskSubtaskUi>>(error, stackTrace),
      data: (allTasks) {
        final byId = {for (final task in allTasks) task.id: task};
        return AsyncData(
          items
              .map(
                (link) {
                  final task = byId[link.targetId];
                  return task == null ? null : TaskSubtaskUi(link: link, task: task);
                },
              )
              .whereType<TaskSubtaskUi>()
              .toList(growable: false),
        );
      },
    ),
  );
});

final taskSubtaskCommandsProvider =
    Provider<TaskSubtaskCommands>(TaskSubtaskCommands.new);

class TaskSubtaskCommands {
  TaskSubtaskCommands(this.ref);

  final Ref ref;

  Future<ExecutionTask> create({
    required ExecutionTask parent,
    required String title,
  }) async {
    if (kIsWeb) {
      throw StateError('Web Preview 不写入生产子任务关系');
    }
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) throw ArgumentError('子任务标题不能为空');

    final userId = await ref.read(currentUserIdProvider.future);
    if (userId == null || userId != parent.userId) {
      throw StateError('请先连接 LifeTrace Cloud');
    }
    final deviceId = await ref.read(deviceIdProvider.future);
    final child = await ref.read(taskRepositoryProvider).createTask(
          userId: userId,
          deviceId: deviceId,
          title: cleanTitle,
          projectId: parent.projectId,
        );

    final links = ref.read(taskEntityLinkRepositoryProvider);
    if (links == null) throw StateError('子任务关系仓储不可用');
    try {
      await links.createLink(
        userId: userId,
        deviceId: deviceId,
        sourceType: DriftTaskRepository.entityType,
        sourceId: parent.id,
        targetType: DriftTaskRepository.entityType,
        targetId: child.id,
        relationType: taskSubtaskRelationType,
      );
    } catch (_) {
      // Do not leave a child task that the user cannot reach from its parent.
      await ref.read(taskRepositoryProvider).deleteTask(
            userId: userId,
            taskId: child.id,
          );
      rethrow;
    }

    _scheduleSync();
    return child;
  }

  Future<void> unlink(TaskSubtaskUi item) async {
    if (kIsWeb) return;
    final repository = ref.read(taskEntityLinkRepositoryProvider);
    if (repository == null) throw StateError('子任务关系仓储不可用');
    await repository.deleteLink(
      userId: item.link.userId,
      linkId: item.link.id,
    );
    _scheduleSync();
  }

  void _scheduleSync() {
    if (kIsWeb) return;
    unawaited(
      ref.read(taskSyncControllerProvider.notifier).syncNow(silent: true),
    );
    unawaited(BackgroundSyncScheduler.enqueueAfterLocalChange());
  }
}
