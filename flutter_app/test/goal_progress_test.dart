import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/domain/project/execution_project.dart';
import 'package:lifetrace_execute/domain/task/execution_task.dart';
import 'package:lifetrace_execute/features/goals/goal_progress.dart';

void main() {
  const now = '2026-09-16T00:00:00.000Z';

  ExecutionProject project(
    String id, {
    String? goalId = 'goal-1',
    ExecutionProjectStatus status = ExecutionProjectStatus.active,
  }) =>
      ExecutionProject(
        id: id,
        userId: 'user-1',
        title: id,
        goalId: goalId,
        status: status,
        createdAt: now,
        updatedAt: now,
        localVersion: 1,
      );

  ExecutionTask task(
    String id,
    String projectId, {
    ExecutionTaskStatus status = ExecutionTaskStatus.todo,
  }) =>
      ExecutionTask(
        id: id,
        userId: 'user-1',
        title: id,
        projectId: projectId,
        status: status,
        createdAt: now,
        updatedAt: now,
        localVersion: 1,
      );

  test('task completion drives goal progress when linked tasks exist', () {
    final progress = goalProjectProgress(
      'goal-1',
      [project('p1'), project('p2')],
      [
        task('t1', 'p1', status: ExecutionTaskStatus.done),
        task('t2', 'p1'),
        task('t3', 'p2', status: ExecutionTaskStatus.done),
        task('other', 'other', status: ExecutionTaskStatus.done),
      ],
    );

    expect(progress.projects, 2);
    expect(progress.tasks, 3);
    expect(progress.completedTasks, 2);
    expect(progress.rate, 67);
  });

  test('project completion yields 100 only when there are no tasks and all complete', () {
    final complete = goalProjectProgress(
      'goal-1',
      [
        project('p1', status: ExecutionProjectStatus.completed),
        project('p2', status: ExecutionProjectStatus.completed),
      ],
      const [],
    );
    final partial = goalProjectProgress(
      'goal-1',
      [
        project('p1', status: ExecutionProjectStatus.completed),
        project('p2'),
      ],
      const [],
    );

    expect(complete.rate, 100);
    expect(partial.rate, 0);
  });

  test('archived and unrelated projects do not affect active goal progress', () {
    final progress = goalProjectProgress(
      'goal-1',
      [
        project('active'),
        project('archived', status: ExecutionProjectStatus.archived),
        project('other', goalId: 'goal-2'),
      ],
      [
        task('active-task', 'active', status: ExecutionTaskStatus.done),
        task('archived-task', 'archived'),
        task('other-task', 'other'),
      ],
    );

    expect(progress.projects, 1);
    expect(progress.tasks, 1);
    expect(progress.completedTasks, 1);
    expect(progress.rate, 100);
  });
}
