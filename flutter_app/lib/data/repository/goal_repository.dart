import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/goal/execution_goal.dart';
import '../local/app_database.dart' as db;
import 'project_database_mapper.dart';
import 'project_repository.dart';
import 'project_wire_mapper.dart';

abstract final class GoalDatabaseMapper {
  static db.Goal toRow(ExecutionGoal goal) => db.Goal(
        id: goal.id,
        userId: goal.userId,
        name: goal.name,
        description: goal.description,
        status: goal.status.wireValue,
        targetAt: goal.targetAt,
        color: goal.color,
        icon: goal.icon,
        sortOrder: goal.sortOrder,
        completedAt: goal.completedAt,
        createdAt: goal.createdAt,
        updatedAt: goal.updatedAt,
        localVersion: goal.localVersion,
        serverVersion: goal.serverVersion,
        modifiedByDevice: goal.modifiedByDevice,
      );

  static ExecutionGoal fromRow(db.Goal row) => ExecutionGoal(
        id: row.id,
        userId: row.userId,
        name: row.name,
        description: row.description,
        status: _status(row.status),
        targetAt: row.targetAt,
        color: row.color,
        icon: row.icon,
        sortOrder: row.sortOrder,
        completedAt: row.completedAt,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        localVersion: row.localVersion,
        serverVersion: row.serverVersion,
        modifiedByDevice: row.modifiedByDevice,
      );
}

abstract final class GoalWireMapper {
  static Map<String, dynamic> toPayload(ExecutionGoal goal) => {
        'meta': {
          'id': goal.id,
          'userId': goal.userId,
          'createdAt': goal.createdAt,
          'updatedAt': goal.updatedAt,
          'deletedAt': null,
          'localVersion': goal.localVersion,
          'serverVersion': goal.serverVersion,
          'modifiedByDevice': goal.modifiedByDevice,
        },
        'name': goal.name,
        'description': goal.description,
        'status': goal.status.wireValue,
        'targetAt': goal.targetAt,
        'color': goal.color,
        'icon': goal.icon,
        'sortOrder': goal.sortOrder,
        'completedAt': goal.completedAt,
      };

  static ExecutionGoal fromPayload(
    Map<String, dynamic> payload, {
    required String serverVersion,
  }) {
    final meta = _requiredMap(payload['meta']);
    final name = _requiredString(payload, 'name');
    if (name.trim().isEmpty) {
      throw const FormatException('Goal name must not be empty');
    }
    return ExecutionGoal(
      id: _requiredString(meta, 'id'),
      userId: _requiredString(meta, 'userId'),
      name: name,
      description: _nullableString(payload['description']),
      status: _status(_requiredString(payload, 'status')),
      targetAt: _nullableString(payload['targetAt']),
      color: _nullableString(payload['color']),
      icon: _nullableString(payload['icon']),
      sortOrder: _int(payload['sortOrder']) ?? 0,
      completedAt: _nullableString(payload['completedAt']),
      createdAt: _requiredString(meta, 'createdAt'),
      updatedAt: _requiredString(meta, 'updatedAt'),
      localVersion: _int(meta['localVersion']) ?? 1,
      serverVersion: serverVersion,
      modifiedByDevice: _nullableString(meta['modifiedByDevice']),
    );
  }
}

abstract interface class GoalRepository {
  Stream<List<ExecutionGoal>> watchGoals(String userId);

  Future<ExecutionGoal> createGoal({
    required String userId,
    required String deviceId,
    required String name,
    String? description,
    String? targetAt,
    String? color,
    String? icon,
    int sortOrder = 0,
  });

  Future<ExecutionGoal> updateGoal({
    required ExecutionGoal goal,
    required String deviceId,
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
  });

  Future<void> deleteGoal({
    required ExecutionGoal goal,
    required String deviceId,
  });
}

class DriftGoalRepository implements GoalRepository {
  DriftGoalRepository(this.database, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  static const entityType = 'execution.goal';

  final db.AppDatabase database;
  final Uuid _uuid;

  @override
  Stream<List<ExecutionGoal>> watchGoals(String userId) {
    final query = database.select(database.goals)
      ..where((table) => table.userId.equals(userId))
      ..orderBy([
        (table) => OrderingTerm.asc(table.sortOrder),
        (table) => OrderingTerm.desc(table.updatedAt),
      ]);
    return query.watch().map(
          (rows) => rows.map(GoalDatabaseMapper.fromRow).toList(growable: false),
        );
  }

  @override
  Future<ExecutionGoal> createGoal({
    required String userId,
    required String deviceId,
    required String name,
    String? description,
    String? targetAt,
    String? color,
    String? icon,
    int sortOrder = 0,
  }) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw ArgumentError.value(name, 'name', '目标名称不能为空');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final goal = ExecutionGoal(
      id: _uuid.v4(),
      userId: userId,
      name: cleanName,
      description: _clean(description),
      status: ExecutionGoalStatus.active,
      targetAt: _clean(targetAt),
      color: _clean(color) ?? '#49715d',
      icon: _clean(icon) ?? 'target',
      sortOrder: sortOrder,
      createdAt: now,
      updatedAt: now,
      localVersion: 1,
      modifiedByDevice: deviceId,
    );
    await _writeLocalChange(goal);
    return goal;
  }

  @override
  Future<ExecutionGoal> updateGoal({
    required ExecutionGoal goal,
    required String deviceId,
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
    final cleanName = (name ?? goal.name).trim();
    if (cleanName.isEmpty) {
      throw ArgumentError.value(cleanName, 'name', '目标名称不能为空');
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final nextStatus = status ?? goal.status;
    String? completedAt = goal.completedAt;
    var clearCompletedAt = false;
    if (nextStatus == ExecutionGoalStatus.completed) {
      completedAt ??= now;
    } else if (nextStatus == ExecutionGoalStatus.active ||
        nextStatus == ExecutionGoalStatus.paused) {
      completedAt = null;
      clearCompletedAt = true;
    }

    final updated = goal.copyWith(
      name: cleanName,
      description: description == null ? null : _clean(description),
      status: nextStatus,
      targetAt: targetAt == null ? null : _clean(targetAt),
      color: color == null ? null : _clean(color),
      icon: icon == null ? null : _clean(icon),
      sortOrder: sortOrder,
      completedAt: completedAt,
      updatedAt: now,
      localVersion: goal.localVersion + 1,
      modifiedByDevice: deviceId,
      clearDescription: clearDescription,
      clearTargetAt: clearTargetAt,
      clearColor: clearColor,
      clearIcon: clearIcon,
      clearCompletedAt: clearCompletedAt,
    );
    await _writeLocalChange(updated);
    return updated;
  }

  @override
  Future<void> deleteGoal({
    required ExecutionGoal goal,
    required String deviceId,
  }) async {
    final existing = await (database.select(database.goals)
          ..where(
            (table) =>
                table.userId.equals(goal.userId) & table.id.equals(goal.id),
          ))
        .getSingleOrNull();
    if (existing == null) return;

    final linkedProjects = await (database.select(database.projects)
          ..where(
            (table) =>
                table.userId.equals(goal.userId) & table.goalId.equals(goal.id),
          ))
        .get();
    final now = DateTime.now().toUtc().toIso8601String();

    await database.transaction(() async {
      for (final row in linkedProjects) {
        final project = ProjectDatabaseMapper.fromRow(row);
        final unlinked = project.copyWith(
          clearGoalId: true,
          updatedAt: now,
          localVersion: project.localVersion + 1,
          modifiedByDevice: deviceId,
        );
        await (database.update(database.projects)
              ..where(
                (table) =>
                    table.userId.equals(project.userId) &
                    table.id.equals(project.id),
              ))
            .write(
          db.ProjectsCompanion(
            goalId: const Value(null),
            updatedAt: Value(unlinked.updatedAt),
            localVersion: Value(unlinked.localVersion),
            modifiedByDevice: Value(unlinked.modifiedByDevice),
          ),
        );
        await database.into(database.syncOutbox).insert(
              db.SyncOutboxCompanion.insert(
                changeId: _uuid.v4(),
                userId: project.userId,
                entityType: DriftProjectRepository.entityType,
                entityId: project.id,
                operation: 'upsert',
                baseServerVersion: project.serverVersion ?? '0',
                clientModifiedAt: now,
                payloadJson: Value(jsonEncode(ProjectWireMapper.toPayload(unlinked))),
                createdAt: now,
              ),
            );
      }

      await database.into(database.syncOutbox).insert(
            db.SyncOutboxCompanion.insert(
              changeId: _uuid.v4(),
              userId: goal.userId,
              entityType: entityType,
              entityId: goal.id,
              operation: 'delete',
              baseServerVersion: existing.serverVersion ?? '0',
              clientModifiedAt: now,
              createdAt: now,
            ),
          );
      await (database.delete(database.goals)
            ..where(
              (table) =>
                  table.userId.equals(goal.userId) & table.id.equals(goal.id),
            ))
          .go();
    });
  }

  Future<void> _writeLocalChange(ExecutionGoal goal) async {
    final payload = jsonEncode(GoalWireMapper.toPayload(goal));
    await database.transaction(() async {
      await database
          .into(database.goals)
          .insertOnConflictUpdate(GoalDatabaseMapper.toRow(goal));
      await database.into(database.syncOutbox).insert(
            db.SyncOutboxCompanion.insert(
              changeId: _uuid.v4(),
              userId: goal.userId,
              entityType: entityType,
              entityId: goal.id,
              operation: 'upsert',
              baseServerVersion: goal.serverVersion ?? '0',
              clientModifiedAt: goal.updatedAt,
              payloadJson: Value(payload),
              createdAt: goal.updatedAt,
            ),
          );
    });
  }
}

class PreviewGoalRepository implements GoalRepository {
  final List<ExecutionGoal> _goals = <ExecutionGoal>[];
  final StreamController<List<ExecutionGoal>> _changes =
      StreamController<List<ExecutionGoal>>.broadcast();
  final Uuid _uuid = const Uuid();

  @override
  Stream<List<ExecutionGoal>> watchGoals(String userId) async* {
    List<ExecutionGoal> snapshot() =>
        _goals.where((goal) => goal.userId == userId).toList(growable: false);
    yield snapshot();
    await for (final _ in _changes.stream) {
      yield snapshot();
    }
  }

  @override
  Future<ExecutionGoal> createGoal({
    required String userId,
    required String deviceId,
    required String name,
    String? description,
    String? targetAt,
    String? color,
    String? icon,
    int sortOrder = 0,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final goal = ExecutionGoal(
      id: _uuid.v4(),
      userId: userId,
      name: name.trim(),
      description: _clean(description),
      status: ExecutionGoalStatus.active,
      targetAt: _clean(targetAt),
      color: _clean(color) ?? '#49715d',
      icon: _clean(icon) ?? 'target',
      sortOrder: sortOrder,
      createdAt: now,
      updatedAt: now,
      localVersion: 1,
      modifiedByDevice: deviceId,
    );
    _goals.add(goal);
    _changes.add(List.unmodifiable(_goals));
    return goal;
  }

  @override
  Future<ExecutionGoal> updateGoal({
    required ExecutionGoal goal,
    required String deviceId,
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
    final now = DateTime.now().toUtc().toIso8601String();
    final nextStatus = status ?? goal.status;
    String? completedAt = goal.completedAt;
    var clearCompletedAt = false;
    if (nextStatus == ExecutionGoalStatus.completed) {
      completedAt ??= now;
    } else if (nextStatus == ExecutionGoalStatus.active ||
        nextStatus == ExecutionGoalStatus.paused) {
      completedAt = null;
      clearCompletedAt = true;
    }
    final updated = goal.copyWith(
      name: name?.trim(),
      description: description == null ? null : _clean(description),
      status: nextStatus,
      targetAt: targetAt == null ? null : _clean(targetAt),
      color: color == null ? null : _clean(color),
      icon: icon == null ? null : _clean(icon),
      sortOrder: sortOrder,
      completedAt: completedAt,
      updatedAt: now,
      localVersion: goal.localVersion + 1,
      modifiedByDevice: deviceId,
      clearDescription: clearDescription,
      clearTargetAt: clearTargetAt,
      clearColor: clearColor,
      clearIcon: clearIcon,
      clearCompletedAt: clearCompletedAt,
    );
    final index = _goals.indexWhere((item) => item.id == goal.id);
    if (index >= 0) _goals[index] = updated;
    _changes.add(List.unmodifiable(_goals));
    return updated;
  }

  @override
  Future<void> deleteGoal({
    required ExecutionGoal goal,
    required String deviceId,
  }) async {
    _goals.removeWhere((item) => item.id == goal.id);
    _changes.add(List.unmodifiable(_goals));
  }
}

ExecutionGoalStatus _status(String value) {
  for (final status in ExecutionGoalStatus.values) {
    if (status.wireValue == value) return status;
  }
  throw FormatException('Unsupported goal status: $value');
}

Map<String, dynamic> _requiredMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw const FormatException('Goal payload meta must be a JSON object');
}

String _requiredString(Map<String, dynamic> json, String name) {
  final value = _nullableString(json[name]);
  if (value == null) throw FormatException('Goal payload is missing $name');
  return value;
}

String? _nullableString(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int? _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '');
}

String? _clean(String? value) {
  final clean = value?.trim();
  return clean == null || clean.isEmpty ? null : clean;
}
