import 'package:oga/router/auth_redirect.dart';
import 'package:oga/router/deep_link_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveAuthRedirect', () {
    test('no redirige mientras auth no está listo', () {
      expect(
        resolveAuthRedirect(
          AuthRedirectInput(
            matchedLocation: '/app',
            uri: Uri.parse('/app'),
            isAuthReady: false,
            isLoggedIn: false,
          ),
        ),
        isNull,
      );
    });

    test('envía a sign-in cuando no hay sesión y auth está listo', () {
      expect(
        resolveAuthRedirect(
          AuthRedirectInput(
            matchedLocation: '/app',
            uri: Uri.parse('/app'),
            isAuthReady: true,
            isLoggedIn: false,
          ),
        ),
        signInPath,
      );
    });

    test('salta sign-in y va al home con sesión activa', () {
      expect(
        resolveAuthRedirect(
          AuthRedirectInput(
            matchedLocation: signInPath,
            uri: Uri.parse(signInPath),
            isAuthReady: true,
            isLoggedIn: true,
          ),
        ),
        '/app',
      );
    });

    test('bloquea app para email sin verificar', () {
      expect(
        resolveAuthRedirect(
          AuthRedirectInput(
            matchedLocation: '/app',
            uri: Uri.parse('/app'),
            isAuthReady: true,
            isLoggedIn: true,
            isEmailVerified: false,
            requiresEmailVerification: true,
          ),
        ),
        '$signInPath?pendingVerification=1',
      );
    });

    test('mantiene sign-in con verificación pendiente', () {
      expect(
        resolveAuthRedirect(
          AuthRedirectInput(
            matchedLocation: signInPath,
            uri: Uri.parse('$signInPath?pendingVerification=1'),
            isAuthReady: true,
            isLoggedIn: true,
            isEmailVerified: false,
            requiresEmailVerification: true,
          ),
        ),
        isNull,
      );
    });

    test('restaura destino pendiente tras login', () {
      expect(
        resolveAuthRedirect(
          AuthRedirectInput(
            matchedLocation: signInPath,
            uri: Uri.parse(signInPath),
            isAuthReady: true,
            isLoggedIn: true,
            takePendingDestination: () => '/invites?familyId=f1',
          ),
        ),
        '/invites?familyId=f1',
      );
    });

    test('resuelve deep link de familia con sesión', () {
      final destination = resolveAuthRedirect(
        AuthRedirectInput(
          matchedLocation: '/family/fam1/stock/item1',
          uri: Uri.parse('/family/fam1/stock/item1'),
          isAuthReady: true,
          isLoggedIn: true,
        ),
      );
      expect(destination, contains('/app'));
      expect(destination, contains('tab=stock'));
      expect(destination, contains('familyId=fam1'));
    });
  });
}
