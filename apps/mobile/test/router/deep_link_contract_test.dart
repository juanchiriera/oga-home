import 'package:craftr_mobile/router/deep_link_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Deep link contract', () {
    test('detecta enlaces de entidad de familia válidos', () {
      expect(
        isFamilyEntityDeepLink(Uri.parse('/family/fam123/invite/token123')),
        isTrue,
      );
      expect(
        isFamilyEntityDeepLink(Uri.parse('/family/fam123/invite')),
        isFalse,
      );
      expect(isFamilyEntityDeepLink(Uri.parse('/invite/token123')), isFalse);
    });

    test('mapea invitación a destino /invites con query esperada', () {
      final destination = resolveFamilyEntityDestination(
        Uri.parse('/family/fam123/invites/token123'),
      );
      final uri = Uri.parse(destination);

      expect(uri.path, '/invites');
      expect(uri.queryParameters['familyId'], 'fam123');
      expect(uri.queryParameters['entityId'], 'token123');
    });

    test('mapea stock a tab stock en /app', () {
      final destination = resolveFamilyEntityDestination(
        Uri.parse('/family/fam123/stock/item-1'),
      );
      final uri = Uri.parse(destination);

      expect(uri.path, '/app');
      expect(uri.queryParameters['tab'], 'stock');
      expect(uri.queryParameters['familyId'], 'fam123');
      expect(uri.queryParameters['entityId'], 'item-1');
    });

    test('mapea recipe a pantalla de preview dedicada', () {
      final destination = resolveFamilyEntityDestination(
        Uri.parse('/family/fam123/recipe/rec-42'),
      );
      final uri = Uri.parse(destination);

      expect(uri.path, '/app/recipes/rec-42');
      expect(uri.queryParameters['familyId'], 'fam123');
    });
  });

  group('Invitación + navegación (integración de módulos)', () {
    test(
      'destino pendiente conserva deeplink resoluble para navegación post-login',
      () {
        final destination = resolveFamilyEntityDestination(
          Uri.parse('/family/fam-1/stock/abc'),
        );
        final sanitized = sanitizePendingDestination(destination);
        final pendingUri = Uri.parse(sanitized!);

        expect(pendingUri.path, '/app');
        expect(pendingUri.queryParameters['tab'], 'stock');
        expect(
          isFamilyEntityDeepLink(Uri.parse('/family/fam-1/stock/abc')),
          isTrue,
        );
      },
    );

    test('rechaza destino pendiente inválido y evita /sign-in', () {
      expect(sanitizePendingDestination(null), isNull);
      expect(sanitizePendingDestination('https://example.com/app'), isNull);
      expect(sanitizePendingDestination('/sign-in'), isNull);
      expect(
        sanitizePendingDestination('/invites?familyId=f1'),
        '/invites?familyId=f1',
      );
    });
  });
}
