import 'package:craftr_mobile/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Bootstrap smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const CraftrApp());
    expect(find.textContaining('Monorepo listo'), findsOneWidget);
  });
}
