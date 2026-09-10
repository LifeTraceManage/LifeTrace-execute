import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/task/execution_task.dart';
import '../local/app_database.dart' as db;

abstract interface class TaskRepository {
  Stream<List<ExecutionTask>> watchTasks(String userId);

  Future<ExecutionTask> createTask({
    required String userId,
    required String deviceId,
    required String title,
    String? description,
    String? projectId,
    ExecutionTaskPriority priority = ExecutionTaskPriority.normal,
    String? dueAt,
    String? scheduledAt,
  });

  Future<ExecutionTask> updateTask({
    required ExecutionTask task,
    required String deviceId,
    String? title,
    String? description,
    String? projectId,
    ExecutionTaskStatus? status,
    ExecutionTaskPriority? priority,
    String? dueAt,
    String? scheduledAt,
  });

  Future<void> deleteTask({required String userId, required String taskId});
}

class DriftTaskRepository implements TaskRepository {
  DriftTaskRepository(this.database, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  static const entityType = 'execution.task';

  final db.AppDatabase database;
  final Uuid _uuid;

  @override
  Stream<List<ExecutionTask>> watchTasks(String userId) {
    final query = database.select(database.tasks)
      ..where((table) => table.userId.equals(userId))
      ..orderBy([(table) => OrderingTerm.desc(table.updatedAt)]);
    return query.watch().map(
          (rows) => rows.map(_toDomain).toList(growable: false),
        );
  }

  @override
  Future<ExecutionTask> createTask({
    required String userId,
    required String deviceId,
    required String title,
    String? description,
    String? projectId,
    ExecutionTaskPriority priority = ExecutionTaskPriority.normal,
    String? dueAt,
    String? scheduledAt,
  }) async {
    if (title.trim().isEmpty) {
      throw ArgumentError.value(title, 'title', '任务标题不能为空');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final task = ExecutionTask(
      id: _uuid.v4(),
      userId: userId,
      title: title.trim(),
      description: _clean(description),
      projectId: _clean(projectId),
      priority: priority,
      dueAt: dueAt,
      scheduledAt: scheduledAt,
      createdAt: now,
      updatedAt: now,
      localVersion: 1,
      modifiedByDevice: deviceId,
    );
    await _writeLocalChange(task);
    return task;
  }

  @override
  Future<ExecutionTask> updateTask({
    required ExecutionTask task,
    required String deviceId,
    String? title,
    String? description,
    String? projectId,
    ExecutionTaskStatus? status,
    ExecutionTaskPriority? priority,
    String? dueAt,
    String? scheduledAt,
  }) async {
    final nextTitle = (title ?? task.title).trim();
    if (nextTitle.isEmpty) {
      throw ArgumentError.value(nextTitle, 'title', '任务标题不能为空');
    }
    final nextStatus = status ?? task.status;
    final now = DateTime.now().toUtc().toIso8601String();
    final completedAt = switch ((task.status, nextStatus)) {
      (_, ExecutionTaskStatus.done) when task.status != ExecutionTaskStatus.done => now,
      (_, ExecutionTaskStatus.done) => task.completedAt,
      _ => null,
    };
    final updated = ExecutionTask(
      id: task.id,
      userId: task.userId,
      title: nextTitle,
      description: description == null ? task.description : _clean(description),
      projectId: projectId == null ? task.projectId : _clean(projectId),
      status: nextStatus,
      priority: priority ?? task.priority,
      dueAt: dueAt ?? task.dueAt,
      scheduledAt: scheduledAt ?? task.scheduledAt,
      completedAt: completedAt,
      createdAt: task.createdAt,
      updatedAt: now,
      localVersion: task.localVersion + 1,
      serverVersion: task.serverVersion,
      modifiedByDevice: deviceId,
    );
    await _writeLocalChange(updated);
    return updated;
  }

  @override
  Future<void> deleteTask({required String userId, required String taskId}) async {
    final existing = await (database.select(database.tasks)
          ..where((table) => table.userId.equals(userId) & table.id.equals(taskId)))
        .getSingleOrNull();
    if (existing == null) return;

    final now = DateTime.now().toUtc().toIso8601String();
    await database.transaction(() async {
      await database.into(database.syncOutbox).insert(
            db.SyncOutboxCompanion.insert(
              changeId: _uuid.v4(),
              userId: userId,
              entityType: entityType,
              entityId: taskId,
              operation: 'delete',
              baseServerVersion: existing.serverVersion ?? '0',
              clientModifiedAt: now,
              createdAt: now,
            ),
          );
      await (database.delete(database.tasks)
            ..where((table) => table.userId.equals(userId) & table.id.equals(taskId)))
          .go();
    });
  }

  Future<void> _writeLocalChange(ExecutionTask task) async {
    final payload = jsonEncode(_toPayload(task));
    final dependencies = jsonEncode([
      if (task.projectId != null)
        {'entityType': 'execution.project', 'entityId': task.projectId},
    ]);

    await database.transaction(() async {
      await database.into(database.tasks).insertOnConflictUpdate(_toRow(task));
      await database.into(database.syncOutbox).insert(
            db.SyncOutboxCompanion.insert(
              changeId: _uuid.v4(),
              userId: task.userId,
              entityType: entityType,
              entityId: task.id,
              operation: 'upsert',
              baseServerVersion: task.serverVersion ?? '0',
              clientModifiedAt: task.updatedAt,
              payloadJson: Value(payload),
              dependenciesJson: Value(dependencies),
              createdAt: task.updatedAt,
            ),
          );
    });
  }

  db.Task _toRow(ExecutionTask task) => db.Task(
        id: task.id,
        userId: task.userId,
        title: task.title,
        description: task.description,
        projectId: task.projectId,
        status: task.status.wireValue,
        priority: task.priority.wireValue,
        dueAt: task.dueAt,
        scheduledAt: task.scheduledAt,
        completedAt: task.completedAt,
        createdAt: task.createdAt,
        updatedAt: task.updatedAt,
        localVersion: task.localVersion,
        serverVersion: task.serverVersion,
        modifiedByDevice: task.modifiedByDevice,
      );

  ExecutionTask _toDomain(db.Task row) => ExecutionTask(
        id: row.id,
        userId: row.userId,
        title: row.title,
        description: row.description,
        projectId: row.projectId,
        status: ExecutionTaskStatus.fromWire(row.status),
        priority: ExecutionTaskPriority.fromWire(row.priority),
        dueAt: row.dueAt,
        scheduledAt: row.scheduledAt,
        completedAt: row.completedAt,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        localVersion: row.localVersion,
        serverVersion: row.serverVersion,
        modifiedByDevice: row.modifiedByDevice,
      );

  Map<String, Object?> _toPayload(ExecutionTask task) => {
        'meta': {'id': task.id, 'schemaVersion': 1},
        'userId': task.userId,
        'title': task.title,
        'description': task.description,
        'projectId': task.projectId,
        'status': task.status.wireValue,
        'priority': task.priority.wireValue,
        'dueAt': task.dueAt,
        'scheduledAt': task.scheduledAt,
        'completedAt': task.completedAt,
        'createdAt': task.createdAt,
        'updatedAt': task.updatedAt,
        'modifiedByDevice': task.modifiedByDevice,
      };

  static String? _clean(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }
}

/// Browser-only review repository. Android production never selects this path.
class PreviewTaskRepository implements TaskRepository {
  PreviewTaskRepository()
      : _tasks = [
          _sample('preview-1', '完成论文 Experiment 1', ExecutionTaskPriority.urgent),
          _sample('preview-2', '修改 LifeTrace API', ExecutionTaskPriority.high),
          _sample('preview-3', '健身', ExecutionTaskPriority.normal),
        ];

  final List<ExecutionTask> _tasks;
  final StreamController<List<ExecutionTask>> _changes =
      StreamController<List<ExecutionTask>>.broadcast();
  final Uuid _uuid = const Uuid();

  static ExecutionTask _sample(
    String id,
    String title,
    ExecutionTaskPriority priority,
  ) {
    final now = DateTime.now().toUtc().toIso8601String();
    return ExecutionTask(
      id: id,
      userId: 'preview-user',
      title: title,
      priority: priority,
      createdAt: now,
      updatedAt: now,
      localVersion: 1,
      modifiedByDevice: 'web-preview',
    );
  }

  @override
  Stream<List<ExecutionTask>> watchTasks(String userId) async* {
    List<ExecutionTask> snapshot() =>
        _tasks.where((task) => task.userId == userId).toList(growable: false);
    yield snapshot();
    await for (final _ in _changes.stream) {
      yield snapshot();
    }
  }

  @override
  Future<ExecutionTask> createTask({
    required String userId,
    required String deviceId,
    required String title,
    String? description,
    String? projectId,
    ExecutionTaskPriority priority = ExecutionTaskPriority.normal,
    String? dueAt,
    String? scheduledAt,
  }) async {
    if (title.trim().isEmpty) throw ArgumentError('任务标题不能为空');
    final now = DateTime.now().toUtc().toIso8601String();
    final task = ExecutionTask(
      id: _uuid.v4(),
      userId: userId,
      title: title.trim(),
      description: description?.trim(),
      projectId: projectId,
      priority: priority,
      dueAt: dueAt,
      scheduledAt: scheduledAt,
      createdAt: now,
      updatedAt: now,
      localVersion: 1,
      modifiedByDevice: deviceId,
    );
    _tasks.insert(0, task);
    _changes.add(List.unmodifiable(_tasks));
    return task;
  }

  @override
  Future<ExecutionTask> updateTask({
    required ExecutionTask task,
    required String deviceId,
    String? title,
    String? description,
    String? projectId,
    ExecutionTaskStatus? status,
    ExecutionTaskPriority? priority,
    String? dueAt,
    String? scheduledAt,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final nextStatus = status ?? task.status;
    final updated = task.copyWith(
      title: title,
      description: description,
      projectId: projectId,
      status: nextStatus,
      priority: priority,
      dueAt: dueAt,
      scheduledAt: scheduledAt,
      completedAt: nextStatus == ExecutionTaskStatus.done ? now : null,
      clearCompletedAt: nextStatus != ExecutionTaskStatus.done,
      updatedAt: now,
      localVersion: task.localVersion + 1,
      modifiedByDevice: deviceId,
    );
    final index = _tasks.indexWhere((item) => item.id == task.id);
    if (index >= 0) _tasks[index] = updated;
    _changes.add(List.unmodifiable(_tasks));
    return updated;
  }

  @override
  Future<void> deleteTask({required String userId, required String taskId}) async {
    _tasks.removeWhere((task) => task.userId == userId && task.id == taskId);
    _changes.add(List.unmodifiable(_tasks));
  }
}
