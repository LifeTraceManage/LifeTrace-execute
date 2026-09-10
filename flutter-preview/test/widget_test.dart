import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute_preview/main.dart';

void main() {
  testWidgets('renders Execute shell with five primary destinations', (tester) async {
    await tester.pumpWidget(const LifeTracePreviewApp());

    expect(find.text('今天'), findsOneWidget);
    expect(find.text('任务'), findsOneWidget);
    expect(find.text('项目'), findsOneWidget);
    expect(find.text('日历'), findsOneWidget);
    expect(find.text('收集'), findsOneWidget);
  });
}
