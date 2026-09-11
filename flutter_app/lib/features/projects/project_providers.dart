import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repository/project_repository.dart';
import '../../data/sync/project_conflict_resolver.dart';
import '../../domain/project/execution_project.dart';
import '../tasks/task_providers.dart';

final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  if (kIsWeb) return PreviewProjectRepository();
  final database = ref.watch(appDatabaseProvider);
  if (database == null) {
    throw StateError('Android production database is unavailable');
  }
  return DriftProjectRepository(database);
});

final projectListProvider = StreamProvider<List<ExecutionProject>>((ref) async* {
  final repository = ref.watch(projectRepositoryProvider);
  final userId = await ref.watch(currentUserIdProvider.future);
  if (userId == null) {
    yield const <ExecutionProject>[];
    return;
  }
  yield* repository.watchProjects(userId);
});

class ProjectConflictUi {
  const ProjectConflictUi({
    required this.conflictId,
    required this.projectId,
    required this.localTitle,
    required this.serverTitle,
    required this.serverDeleted,
    required this.reason,
  });

  final String conflictId;
  final String projectId;
  final String? localTitle;
  final String? serverTitle;
  final bool serverDeleted;
  final String reason;
}

final projectConflictsProvider =
    StreamProvider<List<ProjectConflictUi>>((ref) async* {
  if (kIsWeb) {
    yield const <ProjectConflictUi>[];
    return;
  }
  final database = ref.watch(appDatabaseProvider);
  final userId = await ref.watch(currentUserIdProvider.future);
  if (database == null || userId == null) {
    yield const <ProjectConflictUi>[];
    return;
  }

  final query = database.select(database.syncConflicts)
    ..where(
      (table) =>
          table.userId.equals(userId) &
          table.entityType.equals(DriftProjectRepository.entityType) &
          table.resolved.equals(false),
    )
    ..orderBy([(table) => OrderingTerm.desc(table.createdAt)]);
  yield* query.watch().map(
        (rows) => rows
            .map(
              (row) => ProjectConflictUi(
                conflictId: row.id,
                projectId: row.entityId,
                localTitle: _payloadTitle(row.localPayloadJson),
                serverTitle:
                    row.serverDeleted ? null : _payloadTitle(row.serverPayloadJson),
                serverDeleted: row.serverDeleted,
                reason: row.reason,
              ),
            )
            .toList(growable: false),
      );
});

final projectConflictResolverProvider =
    Provider<ProjectConflictResolver?>((ref) {
  if (kIsWeb) return null;
  final database = ref.watch(appDatabaseProvider);
  return database == null ? null : ProjectConflictResolver(database);
});

final projectCommandsProvider = Provider<ProjectCommands>(ProjectCommands.new);

class ProjectCommands {
  ProjectCommands(this.ref);

  final Ref ref;

  Future<ExecutionProject> create({
    required String title,
    String? description,
    ExecutionProjectStatus status = ExecutionProjectStatus.active,
    String? startAt,
    String? dueAt,
  }) async {
    final project = await ref.read(projectRepositoryProvider).createProject(
          userId: await _requireUserId(),
          deviceId: await ref.read(deviceIdProvider.future),
          title: title,
          description: description,
          status: status,
          startAt: startAt,
          dueAt: dueAt,
        );
    _scheduleSync();
    return project;
  }

  Future<ExecutionProject> update({
    required ExecutionProject project,
    String? title,
    String? description,
    ExecutionProjectStatus? status,
    String? startAt,
    String? dueAt,
    bool clearDescription = false,
    bool clearStartAt = false,
    bool clearDueAt = false,
  }) async {
    final updated = await ref.read(projectRepositoryProvider).updateProject(
          project: project,
          deviceId: await ref.read(deviceIdProvider.future),
          title: title,
          description: description,
          status: status,
          startAt: startAt,
          dueAt: dueAt,
          clearDescription: clearDescription,
          clearStartAt: clearStartAt,
          clearDueAt: clearDueAt,
        );
    _scheduleSync();
    return updated;
  }

  Future<void> delete(ExecutionProject project) async {
    await ref.read(projectRepositoryProvider).deleteProject(
          project: project,
          deviceId: await ref.read(deviceIdProvider.future),
        );
    _scheduleSync();
  }

  Future<void> keepServer(String conflictId) async {
    final resolver = ref.read(projectConflictResolverProvider);
    if (resolver == null) return;
    await resolver.keepServer(conflictId);
    await ref.read(taskSyncControllerProvider.notifier).syncNow(silent: true);
  }

  Future<void> keepLocal(String conflictId) async {
    final resolver = ref.read(projectConflictResolverProvider);
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
