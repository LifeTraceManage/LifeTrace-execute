import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/identity/device_identity_store.dart';
import '../../data/local/app_database.dart';
import '../../data/repository/task_repository.dart';
import '../../domain/task/execution_task.dart';

final appDatabaseProvider = Provider<AppDatabase?>((ref) {
  if (kIsWeb) return null;
  final database = AppDatabase.production();
  ref.onDispose(database.close);
  return database;
});

final currentUserIdProvider = Provider<String>(
  (ref) => kIsWeb ? 'preview-user' : 'local-anonymous',
);

final deviceIdProvider = FutureProvider<String>((ref) async {
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

final taskListProvider = StreamProvider<List<ExecutionTask>>((ref) {
  final repository = ref.watch(taskRepositoryProvider);
  final userId = ref.watch(currentUserIdProvider);
  return repository.watchTasks(userId);
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
    return ref.read(taskRepositoryProvider).createTask(
          userId: ref.read(currentUserIdProvider),
          deviceId: await ref.read(deviceIdProvider.future),
          title: title,
          description: description,
          priority: priority,
        );
  }

  Future<ExecutionTask> toggleDone(ExecutionTask task) async {
    final next = task.isDone ? ExecutionTaskStatus.todo : ExecutionTaskStatus.done;
    return ref.read(taskRepositoryProvider).updateTask(
          task: task,
          deviceId: await ref.read(deviceIdProvider.future),
          status: next,
        );
  }

  Future<ExecutionTask> update({
    required ExecutionTask task,
    String? title,
    String? description,
    ExecutionTaskStatus? status,
    ExecutionTaskPriority? priority,
  }) async {
    return ref.read(taskRepositoryProvider).updateTask(
          task: task,
          deviceId: await ref.read(deviceIdProvider.future),
          title: title,
          description: description,
          status: status,
          priority: priority,
        );
  }

  Future<void> delete(ExecutionTask task) {
    return ref.read(taskRepositoryProvider).deleteTask(
          userId: task.userId,
          taskId: task.id,
        );
  }
}
