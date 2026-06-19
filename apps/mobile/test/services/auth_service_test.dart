import 'package:oga/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isFirebaseAuthActionLink', () {
    test('detecta enlace de verificación de Firebase', () {
      final uri = Uri.parse(
        'https://oga-home.firebaseapp.com/__/auth/action'
        '?mode=verifyEmail&oobCode=abc123&apiKey=test',
      );
      expect(isFirebaseAuthActionLink(uri), isTrue);
    });

    test('ignora rutas sin oobCode', () {
      expect(
        isFirebaseAuthActionLink(
          Uri.parse('https://oga-home.firebaseapp.com/__/auth/action'),
        ),
        isFalse,
      );
    });

    test('ignora deep links de invitación', () {
      expect(
        isFirebaseAuthActionLink(Uri.parse('craftr://invite/token123')),
        isFalse,
      );
    });
  });
}
