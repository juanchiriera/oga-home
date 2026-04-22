import 'package:craftr_mobile/features/auth/sign_in_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Sign-in page smoke', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SignInPage()));
    expect(find.textContaining('Continuar con Google'), findsOneWidget);
  });
}
