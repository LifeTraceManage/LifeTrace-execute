import 'package:flutter_test/flutter_test.dart';
import 'package:lifetrace_execute/main.dart';

void main() {
  testWidgets('unified shell exposes workspace switcher', (tester) async {
    await tester.pumpWidget(const LifeTraceExecuteApp());
    await tester.pumpAndSettle();
    expect(find.text('LifeTrace'), findsOneWidget);
    expect(find.textContaining('Execute'), findsWidgets);
  });
}
