import '../../domain/project/execution_project.dart';
import '../local/app_database.dart' as db;

abstract final class ProjectDatabaseMapper {
  static db.Project toRow(ExecutionProject project) => db.Project(
        id: project.id,
        userId: project.userId,
        title: project.title,
        description: project.description,
        status: project.status.wireValue,
        startAt: project.startAt,
        dueAt: project.dueAt,
        createdAt: project.createdAt,
        updatedAt: project.updatedAt,
        localVersion: project.localVersion,
        serverVersion: project.serverVersion,
        modifiedByDevice: project.modifiedByDevice,
      );

  static ExecutionProject fromRow(db.Project row) => ExecutionProject(
        id: row.id,
        userId: row.userId,
        title: row.title,
        description: row.description,
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
