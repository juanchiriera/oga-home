import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oga/features/profile/account_preferences.dart';

void main() {
  group('account preferences', () {
    test('maps locale codes to supported app locales', () {
      expect(accountLocaleFromCode('en'), const Locale('en', 'US'));
      expect(accountLocaleFromCode('es'), const Locale('es', 'AR'));
      expect(accountLocaleFromCode('fr'), const Locale('es', 'AR'));
    });

    test('defaults currencies from region and includes USD once', () {
      expect(defaultCurrenciesForLocale(const Locale('es', 'AR')), const [
        'ARS',
        'USD',
      ]);
      expect(defaultCurrenciesForLocale(const Locale('en', 'US')), const [
        'USD',
      ]);
    });

    test('normalizes stored currencies and drops unsupported values', () {
      expect(
        normalizeAccountCurrencies(
          const ['usd', 'XXX', 'ARS', 'usd'],
          fallbackLocale: const Locale('en', 'US'),
          requiredCurrency: 'EUR',
        ),
        const ['USD', 'ARS', 'EUR'],
      );
    });
  });
}
