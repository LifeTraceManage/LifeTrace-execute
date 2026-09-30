import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/data/repository/task_repository.dart';
import 'package:lifetrace_execute/domain/task/execution_task.dart';
import 'package:lifetrace_execute/features/tasks/task_providers.dart';
import 'package:lifetrace_execute/main.dart';

void main() {
  testWidgets('renders Flutter production shell with five primary destinations', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(PreviewTaskRepository()),
          currentUserIdProvider.overrideWith((ref) async => 'preview-user'),
          taskSyncCoordinatorProvider.overrideWithValue(null),
        ],
        child: const LifeTraceExecuteApp(),
      ),
    );
    await tester.pump();

    expect(find.text('今天'), findsWidgets);
    expect(find.text('任务'), findsWidgets);
    expect(find.text('项目'), findsWidgets);
    expect(find.text('日历'), findsWidgets);
    expect(find.text('收集'), findsWidgets);
  });


  testWidgets('completed tasks stay accessible from the completed filter', (tester) async {
    final repository = PreviewTaskRepository();
    final completed = await repository.createTask(
      userId: 'preview-user',
      deviceId: 'widget-test',
      title: '已完成测试任务',
    );
    await repository.updateTask(
      task: completed,
      deviceId: 'widget-test',
      status: ExecutionTaskStatus.done,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          taskRepositoryProvider.overrideWithValue(repository),
          currentUserIdProvider.overrideWith((ref) async => 'preview-user'),
          currentSessionProvider.overrideWith((ref) async => null),
          taskSyncCoordinatorProvider.overrideWithValue(null),
        ],
        child: const LifeTraceExecuteApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('任务'));
    await tester.pumpAndSettle();

    final completedTab = find.text('已完成');
    await tester.ensureVisible(completedTab);
    await tester.tap(completedTab);
    await tester.pumpAndSettle();

    expect(find.text('已完成测试任务'), findsOneWidget);
    expect(find.text('完成论文 Experiment 1'), findsNothing);
    expect(find.textContaining('已完成记录 ·'), findsOneWidget);
  });
}
