import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/background/background_sync.dart';
import '../../data/repository/goal_repository.dart';
import '../../data/sync/goal_conflict_resolver.dart';
import '../../domain/goal/execution_goal.dart';
import '../tasks/task_providers.dart';

final goalRepositoryProvider = Provider<GoalRepository>((ref) {
  if (kIsWeb) return PreviewGoalRepository();
  final database = ref.watch(appDatabaseProvider);
  if (database == null) {
    throw StateError('Android production database is unavailable');
  }
  return DriftGoalRepository(database);
});

final goalListProvider = StreamProvider<List<ExecutionGoal>>((ref) async* {
  final repository = ref.watch(goalRepositoryProvider);
  final userId = await ref.watch(currentUserIdProvider.future);
  if (userId == null) {
    yield const <ExecutionGoal>[];
    return;
  }
  yield* repository.watchGoals(userId);
});

class GoalConflictUi {
  const GoalConflictUi({
    required this.conflictId,
    required this.goalId,
    required this.localName,
    required this.serverName,
    required this.serverDeleted,
    required this.reason,
  });

  final String conflictId;
  final String goalId;
  final String? localName;
  final String? serverName;
  final bool serverDeleted;
  final String reason;
}

final goalConflictsProvider =
    StreamProvider<List<GoalConflictUi>>((ref) async* {
  if (kIsWeb) {
    yield const <GoalConflictUi>[];
    return;
  }
  final database = ref.watch(appDatabaseProvider);
  final userId = await ref.watch(currentUserIdProvider.future);
  if (database == null || userId == null) {
    yield const <GoalConflictUi>[];
    return;
  }

  final query = database.select(database.syncConflicts)
    ..where(
      (table) =>
          table.userId.equals(userId) &
          table.entityType.equals(DriftGoalRepository.entityType) &
          table.resolved.equals(false),
    )
    ..orderBy([(table) => OrderingTerm.desc(table.createdAt)]);

  yield* query.watch().map(
        (rows) => rows
            .map(
              (row) => GoalConflictUi(
                conflictId: row.id,
                goalId: row.entityId,
                localName: _payloadName(row.localPayloadJson),
                serverName:
                    row.serverDeleted ? null : _payloadName(row.serverPayloadJson),
                serverDeleted: row.serverDeleted,
                reason: row.reason,
              ),
            )
            .toList(growable: false),
      );
});

final goalConflictResolverProvider = Provider<GoalConflictResolver?>((ref) {
  if (kIsWeb) return null;
  final database = ref.watch(appDatabaseProvider);
  return database == null ? null : GoalConflictResolver(database);
});

final goalCommandsProvider = Provider<GoalCommands>(GoalCommands.new);

class GoalCommands {
  GoalCommands(this.ref);

  final Ref ref;

  Future<ExecutionGoal> create({
    required String name,
    String? description,
    String? targetAt,
    String? color,
    String? icon,
    int sortOrder = 0,
  }) async {
    final goal = await ref.read(goalRepositoryProvider).createGoal(
          userId: await _requireUserId(),
          deviceId: await ref.read(deviceIdProvider.future),
          name: name,
          description: description,
          targetAt: targetAt,
          color: color,
          icon: icon,
          sortOrder: sortOrder,
        );
    _scheduleSync();
    return goal;
  }

  Future<ExecutionGoal> update({
    required ExecutionGoal goal,
    String? name,
    String? description,
    ExecutionGoalStatus? status,
    String? targetAt,
    String? color,
    String? icon,
    int? sortOrder,
    bool clearDescription = false,
    bool clearTargetAt = false,
    bool clearColor = false,
    bool clearIcon = false,
  }) async {
    final updated = await ref.read(goalRepositoryProvider).updateGoal(
          goal: goal,
          deviceId: await ref.read(deviceIdProvider.future),
          name: name,
          description: description,
          status: status,
          targetAt: targetAt,
          color: color,
          icon: icon,
          sortOrder: sortOrder,
          clearDescription: clearDescription,
          clearTargetAt: clearTargetAt,
          clearColor: clearColor,
          clearIcon: clearIcon,
        );
    _scheduleSync();
    return updated;
  }

  Future<void> delete(ExecutionGoal goal) async {
    await ref.read(goalRepositoryProvider).deleteGoal(
          goal: goal,
          deviceId: await ref.read(deviceIdProvider.future),
        );
    _scheduleSync();
  }

  Future<void> keepServer(String conflictId) async {
    final resolver = ref.read(goalConflictResolverProvider);
    if (resolver == null) return;
    await resolver.keepServer(conflictId);
    await ref.read(taskSyncControllerProvider.notifier).syncNow(silent: true);
  }

  Future<void> keepLocal(String conflictId) async {
    final resolver = ref.read(goalConflictResolverProvider);
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
    unawaited(BackgroundSyncScheduler.enqueueAfterLocalChange());
  }
}

String? _payloadName(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final value = jsonDecode(raw);
    if (value is! Map) return null;
    final name = value['name']?.toString().trim();
    return name == null || name.isEmpty ? null : name;
  } catch (_) {
    return null;
  }
}
