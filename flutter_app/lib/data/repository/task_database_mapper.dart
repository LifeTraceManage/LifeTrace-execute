import '../../domain/task/execution_task.dart';
import '../local/app_database.dart' as db;

abstract final class TaskDatabaseMapper {
  static db.Task toRow(ExecutionTask task) => db.Task(
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

  static ExecutionTask fromRow(db.Task row) => ExecutionTask(
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
}
