import 'package:drift/drift.dart';

import '../../domain/project/execution_project.dart';
import '../local/app_database.dart' as db;

abstract final class ProjectDatabaseMapper {
  static db.Project toRow(ExecutionProject project) => db.Project(
        id: project.id,
        userId: project.userId,
        title: project.title,
        description: project.description,
        goalId: project.goalId,
        status: project.status.wireValue,
        startAt: project.startAt,
        dueAt: project.dueAt,
        createdAt: project.createdAt,
        updatedAt: project.updatedAt,
        localVersion: project.localVersion,
        serverVersion: project.serverVersion,
        modifiedByDevice: project.modifiedByDevice,
      );

  static db.ProjectsCompanion toCompanion(ExecutionProject project) =>
      db.ProjectsCompanion(
        id: Value(project.id),
        userId: Value(project.userId),
        title: Value(project.title),
        description: Value(project.description),
        goalId: Value(project.goalId),
        status: Value(project.status.wireValue),
        startAt: Value(project.startAt),
        dueAt: Value(project.dueAt),
        createdAt: Value(project.createdAt),
        updatedAt: Value(project.updatedAt),
        localVersion: Value(project.localVersion),
        serverVersion: Value(project.serverVersion),
        modifiedByDevice: Value(project.modifiedByDevice),
      );

  static ExecutionProject fromRow(db.Project row) => ExecutionProject(
        id: row.id,
        userId: row.userId,
        title: row.title,
        description: row.description,
        goalId: row.goalId,
        status: ExecutionProjectStatus.fromWire(row.status),
        startAt: row.startAt,
        dueAt: row.dueAt,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        localVersion: row.localVersion,
        serverVersion: row.serverVersion,
        modifiedByDevice: row.modifiedByDevice,
      );
}
