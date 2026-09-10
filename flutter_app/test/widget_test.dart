import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/main.dart';

void main() {
  testWidgets('renders Flutter production shell with five primary destinations', (tester) async {
    await tester.pumpWidget(const LifeTraceExecuteApp());

    expect(find.text('今天'), findsWidgets);
    expect(find.text('任务'), findsWidgets);
    expect(find.text('项目'), findsWidgets);
    expect(find.text('日历'), findsWidgets);
    expect(find.text('收集'), findsWidgets);
  });
}
