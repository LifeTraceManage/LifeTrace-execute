import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/project/execution_project.dart';
import '../local/app_database.dart' as db;
import 'project_database_mapper.dart';
import 'project_wire_mapper.dart';
import 'task_database_mapper.dart';
import 'task_repository.dart';
import 'task_wire_mapper.dart';

abstract interface class ProjectRepository {
  Stream<List<ExecutionProject>> watchProjects(String userId);

  Future<ExecutionProject> createProject({
    required String userId,
    required String deviceId,
    required String title,
    String? description,
    ExecutionProjectStatus status = ExecutionProjectStatus.active,
    String? startAt,
    String? dueAt,
  });

  Future<ExecutionProject> updateProject({
    required ExecutionProject project,
    required String deviceId,
    String? title,
    String? description,
    ExecutionProjectStatus? status,
    String? startAt,
    String? dueAt,
    bool clearDescription = false,
    bool clearStartAt = false,
    bool clearDueAt = false,
  });

  Future<void> deleteProject({
    required ExecutionProject project,
    required String deviceId,
  });
}

class DriftProjectRepository implements ProjectRepository {
  DriftProjectRepository(this.database, {Uuid? uuid})
      : _uuid = uuid ?? const Uuid();

  static const entityType = 'execution.project';

  final db.AppDatabase database;
  final Uuid _uuid;

  @override
  Stream<List<ExecutionProject>> watchProjects(String userId) {
    final query = database.select(database.projects)
      ..where((table) => table.userId.equals(userId))
      ..orderBy([(table) => OrderingTerm.desc(table.updatedAt)]);
    return query.watch().map(
          (rows) =>
              rows.map(ProjectDatabaseMapper.fromRow).toList(growable: false),
        );
  }

  @override
  Future<ExecutionProject> createProject({
    required String userId,
    required String deviceId,
    required String title,
    String? description,
    ExecutionProjectStatus status = ExecutionProjectStatus.active,
    String? startAt,
    String? dueAt,
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      throw ArgumentError.value(title, 'title', '项目标题不能为空');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final project = ExecutionProject(
      id: _uuid.v4(),
      userId: userId,
      title: cleanTitle,
      description: _clean(description),
      status: status,
      startAt: _clean(startAt),
      dueAt: _clean(dueAt),
      createdAt: now,
      updatedAt: now,
      localVersion: 1,
      modifiedByDevice: deviceId,
    );
    await _writeLocalChange(project);
    return project;
  }

  @override
  Future<ExecutionProject> updateProject({
    required ExecutionProject project,
    required String deviceId,
    String? title,
    String? description,
    ExecutionProjectStatus? status,
    String? startAt,
    String? dueAt,
    bool clearDescription = false,
    bool clearStartAt = false,
    bool clearDueAt = false,
  }) async {
    final nextTitle = (title ?? project.title).trim();
    if (nextTitle.isEmpty) {
      throw ArgumentError.value(nextTitle, 'title', '项目标题不能为空');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final updated = ExecutionProject(
      id: project.id,
      userId: project.userId,
      title: nextTitle,
      description: clearDescription
          ? null
          : description == null
              ? project.description
              : _clean(description),
      status: status ?? project.status,
      startAt: clearStartAt
          ? null
          : startAt == null
              ? project.startAt
              : _clean(startAt),
      dueAt: clearDueAt
          ? null
          : dueAt == null
              ? project.dueAt
              : _clean(dueAt),
      createdAt: project.createdAt,
      updatedAt: now,
      localVersion: project.localVersion + 1,
      serverVersion: project.serverVersion,
      modifiedByDevice: deviceId,
    );
    await _writeLocalChange(updated);
    return updated;
  }

  @override
  Future<void> deleteProject({
    required ExecutionProject project,
    required String deviceId,
  }) async {
    final existing = await (database.select(database.projects)
          ..where(
            (table) =>
                table.userId.equals(project.userId) &
                table.id.equals(project.id),
          ))
        .getSingleOrNull();
    if (existing == null) return;

    final linkedTasks = await (database.select(database.tasks)
          ..where(
            (table) =>
                table.userId.equals(project.userId) &
                table.projectId.equals(project.id),
          ))
        .get();
    final now = DateTime.now().toUtc().toIso8601String();

    await database.transaction(() async {
      for (final row in linkedTasks) {
        final task = TaskDatabaseMapper.fromRow(row);
        final unlinked = task.copyWith(
          clearProjectId: true,
          updatedAt: now,
          localVersion: task.localVersion + 1,
          modifiedByDevice: deviceId,
        );
        await (database.update(database.tasks)
              ..where(
                (table) =>
                    table.userId.equals(task.userId) &
                    table.id.equals(task.id),
              ))
            .write(
          db.TasksCompanion(
            projectId: const Value(null),
            updatedAt: Value(unlinked.updatedAt),
            localVersion: Value(unlinked.localVersion),
            modifiedByDevice: Value(unlinked.modifiedByDevice),
          ),
        );
        await database.into(database.syncOutbox).insert(
              db.SyncOutboxCompanion.insert(
                changeId: _uuid.v4(),
                userId: task.userId,
                entityType: DriftTaskRepository.entityType,
                entityId: task.id,
                operation: 'upsert',
                baseServerVersion: task.serverVersion ?? '0',
                clientModifiedAt: now,
                payloadJson: Value(jsonEncode(TaskWireMapper.toPayload(unlinked))),
                dependenciesJson: const Value('[]'),
                createdAt: now,
              ),
            );
      }

      await database.into(database.syncOutbox).insert(
            db.SyncOutboxCompanion.insert(
              changeId: _uuid.v4(),
              userId: project.userId,
              entityType: entityType,
              entityId: project.id,
              operation: 'delete',
              baseServerVersion: existing.serverVersion ?? '0',
              clientModifiedAt: now,
              createdAt: now,
            ),
          );
      await (database.delete(database.projects)
            ..where(
              (table) =>
                  table.userId.equals(project.userId) &
                  table.id.equals(project.id),
            ))
          .go();
    });
  }

  Future<void> _writeLocalChange(ExecutionProject project) async {
    final payload = jsonEncode(ProjectWireMapper.toPayload(project));
    await database.transaction(() async {
      await database
          .into(database.projects)
          .insertOnConflictUpdate(ProjectDatabaseMapper.toRow(project));
      await database.into(database.syncOutbox).insert(
            db.SyncOutboxCompanion.insert(
              changeId: _uuid.v4(),
              userId: project.userId,
              entityType: entityType,
              entityId: project.id,
              operation: 'upsert',
              baseServerVersion: project.serverVersion ?? '0',
              clientModifiedAt: project.updatedAt,
              payloadJson: Value(payload),
              createdAt: project.updatedAt,
            ),
          );
    });
  }

  static String? _clean(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }
}

/// Browser-only review repository. Android production never selects this path.
class PreviewProjectRepository implements ProjectRepository {
  PreviewProjectRepository()
      : _projects = [
          _sample(
            id: 'preview-project-life',
            title: 'LifeTrace',
            description: '个人管理平台',
            dueAt: '2026-09-30T23:59:00.000Z',
          ),
          _sample(
            id: 'preview-project-research',
            title: 'Academic Research',
            description: 'Quadrotor + SMF + MPC',
            dueAt: '2026-10-15T23:59:00.000Z',
          ),
          _sample(
            id: 'preview-project-growth',
            title: '个人成长',
            description: '健康 · 学习 · 生活',
            dueAt: '2026-12-31T23:59:00.000Z',
          ),
        ];

  final List<ExecutionProject> _projects;
  final StreamController<List<ExecutionProject>> _changes =
      StreamController<List<ExecutionProject>>.broadcast();
  final Uuid _uuid = const Uuid();

  static ExecutionProject _sample({
    required String id,
    required String title,
    required String description,
    required String dueAt,
  }) {
    const now = '2026-09-11T00:00:00.000Z';
    return ExecutionProject(
      id: id,
      userId: 'preview-user',
      title: title,
      description: description,
      dueAt: dueAt,
      createdAt: now,
      updatedAt: now,
      localVersion: 1,
      modifiedByDevice: 'web-preview',
    );
  }

  @override
  Stream<List<ExecutionProject>> watchProjects(String userId) async* {
    List<ExecutionProject> snapshot() => _projects
        .where((project) => project.userId == userId)
        .toList(growable: false);
    yield snapshot();
    await for (final _ in _changes.stream) {
      yield snapshot();
    }
  }

  @override
  Future<ExecutionProject> createProject({
    required String userId,
    required String deviceId,
    required String title,
    String? description,
    ExecutionProjectStatus status = ExecutionProjectStatus.active,
    String? startAt,
    String? dueAt,
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) throw ArgumentError('项目标题不能为空');
    final now = DateTime.now().toUtc().toIso8601String();
    final project = ExecutionProject(
      id: _uuid.v4(),
      userId: userId,
      title: cleanTitle,
      description: _clean(description),
      status: status,
      startAt: _clean(startAt),
      dueAt: _clean(dueAt),
      createdAt: now,
      updatedAt: now,
      localVersion: 1,
      modifiedByDevice: deviceId,
    );
    _projects.insert(0, project);
    _changes.add(List.unmodifiable(_projects));
    return project;
  }

  @override
  Future<ExecutionProject> updateProject({
    required ExecutionProject project,
    required String deviceId,
    String? title,
    String? description,
    ExecutionProjectStatus? status,
    String? startAt,
    String? dueAt,
    bool clearDescription = false,
    bool clearStartAt = false,
    bool clearDueAt = false,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final updated = project.copyWith(
      title: title?.trim(),
      description: description == null ? null : _clean(description),
      status: status,
      startAt: startAt == null ? null : _clean(startAt),
      dueAt: dueAt == null ? null : _clean(dueAt),
      updatedAt: now,
      localVersion: project.localVersion + 1,
      modifiedByDevice: deviceId,
      clearDescription: clearDescription,
      clearStartAt: clearStartAt,
      clearDueAt: clearDueAt,
    );
    final index = _projects.indexWhere((item) => item.id == project.id);
    if (index >= 0) _projects[index] = updated;
    _changes.add(List.unmodifiable(_projects));
    return updated;
  }

  @override
  Future<void> deleteProject({
    required ExecutionProject project,
    required String deviceId,
  }) async {
    _projects.removeWhere((item) => item.id == project.id);
    _changes.add(List.unmodifiable(_projects));
  }

  static String? _clean(String? value) {
    final clean = value?.trim();
    return clean == null || clean.isEmpty ? null : clean;
  }
}
