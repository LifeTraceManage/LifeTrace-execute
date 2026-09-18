import '../../domain/project/execution_project.dart';
import '../../domain/task/execution_task.dart';

class GoalProgress {
  const GoalProgress({
    required this.projects,
    required this.completedProjects,
    required this.tasks,
    required this.completedTasks,
    required this.rate,
  });

  final int projects;
  final int completedProjects;
  final int tasks;
  final int completedTasks;

  /// Integer percentage in the range 0..100, matching the shared LifeTrace
  /// Goal semantics: task completion drives progress when tasks exist; when a
  /// goal has projects but no tasks it reaches 100% only when every project is
  /// complete.
  final int rate;
}

GoalProgress goalProjectProgress(
  String goalId,
  Iterable<ExecutionProject> projects,
  Iterable<ExecutionTask> tasks,
) {
  final ownedProjects = projects
      .where(
        (project) =>
            project.goalId == goalId &&
            project.status != ExecutionProjectStatus.archived,
      )
      .toList(growable: false);
  final projectIds = ownedProjects.map((project) => project.id).toSet();
  final ownedTasks = tasks
      .where((task) => task.projectId != null && projectIds.contains(task.projectId))
      .toList(growable: false);

  final completedProjects = ownedProjects.where((project) => project.isCompleted).length;
  final completedTasks = ownedTasks.where((task) => task.isDone).length;

  final rate = ownedTasks.isNotEmpty
      ? ((completedTasks / ownedTasks.length) * 100).round()
      : completedProjects > 0 && completedProjects == ownedProjects.length
          ? 100
          : 0;

  return GoalProgress(
    projects: ownedProjects.length,
    completedProjects: completedProjects,
    tasks: ownedTasks.length,
    completedTasks: completedTasks,
    rate: rate,
  );
}
