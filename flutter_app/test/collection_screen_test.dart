import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/domain/collection/execution_memo.dart';
import 'package:lifetrace_execute/features/collection/collection_providers.dart';
import 'package:lifetrace_execute/main.dart';

void main() {
  testWidgets('Inbox quick capture uses compact integrated actions', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          inboxMemoListProvider.overrideWithValue(
            const AsyncData<List<ExecutionMemo>>(<ExecutionMemo>[]),
          ),
          collectionConflictsProvider.overrideWith(
            (ref) => Stream.value(const <CollectionConflictUi>[]),
          ),
        ],
        child: MaterialApp(
          theme: buildTheme(),
          home: const Scaffold(body: Collection()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('快速收集'), findsOneWidget);
    for (final label in const ['文本', '想法', '链接', '语音', '图片', '文件']) {
      expect(find.text(label), findsWidgets);
    }

    final legacyLargeAction = find.byWidgetPredicate((widget) {
      if (widget is! Container || widget.constraints == null) return false;
      return widget.constraints!.minWidth == 96 &&
          widget.constraints!.maxWidth == 96 &&
          widget.constraints!.minHeight == 68 &&
          widget.constraints!.maxHeight == 68;
    });
    expect(legacyLargeAction, findsNothing);
  });
}
