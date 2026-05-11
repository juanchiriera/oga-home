import 'dart:ui';

import 'package:oga/features/expenses/expense_money.dart';

const kSupportedAccountLocaleCodes = <String>['es', 'en'];

Locale accountLocaleFromCode(String? rawCode) {
  final code = rawCode?.trim().toLowerCase();
  return switch (code) {
    'en' => const Locale('en', 'US'),
    'es' => const Locale('es', 'AR'),
    _ => const Locale('es', 'AR'),
  };
}

String accountLocaleCodeFromLocale(Locale locale) {
  return locale.languageCode == 'en' ? 'en' : 'es';
}

String defaultCurrencyForLocale(Locale locale) {
  final country = locale.countryCode?.toUpperCase();
  return switch (country) {
    'AR' => 'ARS',
    'ES' ||
    'FR' ||
    'DE' ||
    'IT' ||
    'PT' ||
    'IE' ||
    'NL' ||
    'BE' ||
    'AT' ||
    'FI' ||
    'GR' => 'EUR',
    _ => 'USD',
  };
}

List<String> defaultCurrenciesForLocale(Locale locale) {
  return normalizeAccountCurrencies([
    defaultCurrencyForLocale(locale),
    'USD',
  ], fallbackLocale: locale);
}

List<String> normalizeAccountCurrencies(
  Iterable<Object?>? raw, {
  required Locale fallbackLocale,
  String? requiredCurrency,
}) {
  final normalized = <String>[];
  void addIfSupported(Object? value) {
    final code = value?.toString().trim().toUpperCase();
    if (code == null || code.isEmpty) {
      return;
    }
    if (kSupportedCurrencies.contains(code) && !normalized.contains(code)) {
      normalized.add(code);
    }
  }

  raw?.forEach(addIfSupported);
  addIfSupported(requiredCurrency);
  if (normalized.isEmpty) {
    defaultCurrenciesForLocale(fallbackLocale).forEach(addIfSupported);
  }
  return normalized;
}
