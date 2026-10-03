import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/data/repository/task_repository.dart';
import 'package:lifetrace_execute/features/tasks/task_providers.dart';
import 'package:lifetrace_execute/main.dart';

void main() {
  testWidgets('unified shell exposes workspace switcher', (tester) async {
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
    expect(find.text('LifeTrace'), findsOneWidget);
    expect(find.textContaining('Execute'), findsWidgets);
  });
}
