import 'package:flutter_test/flutter_test.dart';
import 'package:scaner/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const ScanerApp());
    expect(find.text('AI 智能掃描器'), findsOneWidget);
  });
}
