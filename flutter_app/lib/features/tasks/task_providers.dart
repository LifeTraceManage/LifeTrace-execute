import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/cloud/cloud_session_manager.dart';
import '../../core/cloud/secure_session_store.dart';
import '../../core/identity/device_identity_store.dart';
import '../../data/local/app_database.dart';
import '../../data/repository/task_repository.dart';
import '../../data/sync/task_conflict_resolver.dart';
import '../../data/sync/task_sync_coordinator.dart';
import '../../domain/task/execution_task.dart';

const executeClientVersion = '0.3.0';

final appDatabaseProvider = Provider<AppDatabase?>((ref) {
  if (kIsWeb) return null;
  final database = AppDatabase.production();
  ref.onDispose(database.close);
  return database;
});

final cloudSessionManagerProvider = Provider<CloudSessionManager>((ref) {
  return CloudSessionManager();
});

final currentSessionProvider = FutureProvider<StoredCloudSession?>((ref) async {
  if (kIsWeb) return null;
  return ref.watch(cloudSessionManagerProvider).currentSession();
});

final currentUserIdProvider = FutureProvider<String?>((ref) async {
  if (kIsWeb) return 'preview-user';
  return (await ref.watch(currentSessionProvider.future))?.userId;
});

final deviceIdProvider = FutureProvider<String>((ref) async {
  if (kIsWeb) return 'web-preview';
  return DeviceIdentityStore().getOrCreate();
});

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  if (kIsWeb) return PreviewTaskRepository();
  final database = ref.watch(appDatabaseProvider);
  if (database == null) {
    throw StateError('Android production database is unavailable');
  }
  return DriftTaskRepository(database);
});

final taskListProvider = StreamProvider<List<ExecutionTask>>((ref) async* {
  final repository = ref.watch(taskRepositoryProvider);
  final userId = await ref.watch(currentUserIdProvider.future);
  if (userId == null) {
    yield const <ExecutionTask>[];
    return;
  }
  yield* repository.watchTasks(userId);
});

final taskSyncCoordinatorProvider = Provider<TaskSyncCoordinator?>((ref) {
  if (kIsWeb) return null;
  final database = ref.watch(appDatabaseProvider);
  if (database == null) return null;
  return TaskSyncCoordinator(
    database: database,
    sessionManager: ref.watch(cloudSessionManagerProvider),
    deviceIdLoader: () => ref.read(deviceIdProvider.future),
    clientVersion: executeClientVersion,
  );
});

final taskConflictResolverProvider = Provider<TaskConflictResolver?>((ref) {
  if (kIsWeb) return null;
  final database = ref.watch(appDatabaseProvider);
  return database == null ? null : TaskConflictResolver(database);
});

final taskPendingSyncCountProvider = StreamProvider<int>((ref) async* {
  if (kIsWeb) {
    yield 0;
    return;
  }
  final database = ref.watch(appDatabaseProvider);
  final userId = await ref.watch(currentUserIdProvider.future);
  if (database == null || userId == null) {
    yield 0;
    return;
  }
  final count = database.syncOutbox.changeId.count();
  final query = database.selectOnly(database.syncOutbox)
    ..addColumns([count])
    ..where(
      database.syncOutbox.userId.equals(userId) &
          database.syncOutbox.blocked.equals(false),
    );
  yield* query.watchSingle().map((row) => row.read(count) ?? 0);
});

final taskBlockedSyncCountProvider = StreamProvider<int>((ref) async* {
  if (kIsWeb) {
    yield 0;
    return;
  }
  final database = ref.watch(appDatabaseProvider);
  final userId = await ref.watch(currentUserIdProvider.future);
  if (database == null || userId == null) {
    yield 0;
    return;
  }
  final count = database.syncOutbox.changeId.count();
  final query = database.selectOnly(database.syncOutbox)
    ..addColumns([count])
    ..where(
      database.syncOutbox.userId.equals(userId) &
          database.syncOutbox.blocked.equals(true),
    );
  yield* query.watchSingle().map((row) => row.read(count) ?? 0);
});

class TaskConflictUi {
  const TaskConflictUi({
    required this.conflictId,
    required this.taskId,
    required this.localTitle,
    required this.serverTitle,
    required this.serverDeleted,
    required this.reason,
  });

  final String conflictId;
  final String taskId;
  final String? localTitle;
  final String? serverTitle;
  final bool serverDeleted;
  final String reason;
}

final taskConflictsProvider = StreamProvider<List<TaskConflictUi>>((ref) async* {
  if (kIsWeb) {
    yield const <TaskConflictUi>[];
    return;
  }
  final database = ref.watch(appDatabaseProvider);
  final userId = await ref.watch(currentUserIdProvider.future);
  if (database == null || userId == null) {
    yield const <TaskConflictUi>[];
    return;
  }

  final query = database.select(database.syncConflicts)
    ..where(
      (table) => table.userId.equals(userId) & table.resolved.equals(false),
    )
    ..orderBy([(table) => OrderingTerm.desc(table.createdAt)]);
  yield* query.watch().map(
        (rows) => rows
            .map(
              (row) => TaskConflictUi(
                conflictId: row.id,
                taskId: row.entityId,
                localTitle: _payloadTitle(row.localPayloadJson),
                serverTitle: row.serverDeleted
                    ? null
                    : _payloadTitle(row.serverPayloadJson),
                serverDeleted: row.serverDeleted,
                reason: row.reason,
              ),
            )
            .toList(growable: false),
      );
});

final taskCommandsProvider = Provider<TaskCommands>((ref) {
  return TaskCommands(ref);
});

class TaskCommands {
  TaskCommands(this.ref);

  final Ref ref;

  Future<ExecutionTask> create({
    required String title,
    String? description,
    ExecutionTaskPriority priority = ExecutionTaskPriority.normal,
  }) async {
    final task = await ref.read(taskRepositoryProvider).createTask(
          userId: await _requireUserId(),
          deviceId: await ref.read(deviceIdProvider.future),
          title: title,
          description: description,
          priority: priority,
        );
    _scheduleSync();
    return task;
  }

  Future<ExecutionTask> toggleDone(ExecutionTask task) async {
    final next = task.isDone ? ExecutionTaskStatus.todo : ExecutionTaskStatus.done;
    final updated = await ref.read(taskRepositoryProvider).updateTask(
          task: task,
          deviceId: await ref.read(deviceIdProvider.future),
          status: next,
        );
    _scheduleSync();
    return updated;
  }

  Future<ExecutionTask> update({
    required ExecutionTask task,
    String? title,
    String? description,
    ExecutionTaskStatus? status,
    ExecutionTaskPriority? priority,
  }) async {
    final updated = await ref.read(taskRepositoryProvider).updateTask(
          task: task,
          deviceId: await ref.read(deviceIdProvider.future),
          title: title,
          description: description,
          status: status,
          priority: priority,
        );
    _scheduleSync();
    return updated;
  }

  Future<void> delete(ExecutionTask task) async {
    await ref.read(taskRepositoryProvider).deleteTask(
          userId: task.userId,
          taskId: task.id,
        );
    _scheduleSync();
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
}

class TaskSyncController extends AsyncNotifier<TaskSyncSummary?> {
  @override
  FutureOr<TaskSyncSummary?> build() => null;

  Future<TaskSyncSummary?> syncNow({bool silent = false}) async {
    final coordinator = ref.read(taskSyncCoordinatorProvider);
    if (coordinator == null) return null;

    if (silent) {
      try {
        return await coordinator.syncNow();
      } catch (_) {
        return null;
      }
    }

    state = const AsyncLoading();
    final next = await AsyncValue.guard(coordinator.syncNow);
    state = next;
    return next.valueOrNull;
  }

  Future<void> keepServer(String conflictId) async {
    final resolver = ref.read(taskConflictResolverProvider);
    if (resolver == null) return;
    state = const AsyncLoading();
    try {
      await resolver.keepServer(conflictId);
      await syncNow();
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> keepLocal(String conflictId) async {
    final resolver = ref.read(taskConflictResolverProvider);
    if (resolver == null) return;
    state = const AsyncLoading();
    try {
      await resolver.keepLocal(
        conflictId: conflictId,
        deviceId: await ref.read(deviceIdProvider.future),
      );
      await syncNow();
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }
}

final taskSyncControllerProvider =
    AsyncNotifierProvider<TaskSyncController, TaskSyncSummary?>(
  TaskSyncController.new,
);

final cloudCommandsProvider = Provider<CloudCommands>((ref) => CloudCommands(ref));

class CloudCommands {
  CloudCommands(this.ref);

  final Ref ref;

  Future<StoredCloudSession> login({
    required String baseUrl,
    required String email,
    required String password,
    required String deviceName,
  }) async {
    final session = await ref.read(cloudSessionManagerProvider).login(
          baseUrl: baseUrl,
          email: email,
          password: password,
          deviceName: deviceName,
          clientVersion: executeClientVersion,
        );
    _refreshSessionState();
    return session;
  }

  Future<void> logout() async {
    await ref.read(cloudSessionManagerProvider).logout();
    _refreshSessionState();
  }

  void _refreshSessionState() {
    ref.invalidate(currentSessionProvider);
    ref.invalidate(currentUserIdProvider);
    ref.invalidate(taskListProvider);
    ref.invalidate(taskPendingSyncCountProvider);
    ref.invalidate(taskBlockedSyncCountProvider);
    ref.invalidate(taskConflictsProvider);
  }
}

String? _payloadTitle(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final value = jsonDecode(raw);
    if (value is! Map) return null;
    final title = value['title']?.toString().trim();
    return title == null || title.isEmpty ? null : title;
  } catch (_) {
    return null;
  }
}
