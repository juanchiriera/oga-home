import 'package:flutter/widgets.dart' show Locale;
import 'package:intl/intl.dart';

const kSupportedCurrencies = <String>['ARS', 'USD', 'EUR'];

String normalizeCurrency(String? raw, {required String fallback}) {
  final value = raw?.trim().toUpperCase();
  if (value == null || value.isEmpty) {
    return fallback;
  }
  if (!kSupportedCurrencies.contains(value)) {
    return fallback;
  }
  return value;
}

String expenseCurrency(Map<String, dynamic> data, {required String fallback}) {
  return normalizeCurrency(data['currency'] as String?, fallback: fallback);
}

double expenseAmount(Map<String, dynamic> data) {
  final amount = (data['amount'] as num?)?.toDouble() ?? 0;
  if (amount <= 0) {
    return 0;
  }
  return amount;
}

void addToCurrencyTotals(
  Map<String, double> totals,
  Map<String, dynamic> data, {
  required String fallbackCurrency,
}) {
  final amount = expenseAmount(data);
  if (amount <= 0) {
    return;
  }
  final currency = expenseCurrency(data, fallback: fallbackCurrency);
  totals[currency] = (totals[currency] ?? 0) + amount;
}

/// ICU locale tag for numeric patterns (separators), aligned with app locales.
String moneyLocaleTag(Locale locale) {
  switch (locale.languageCode) {
    case 'en':
      return 'en_US';
    case 'es':
    default:
      return 'es_AR';
  }
}

String currencySymbol(String currency) {
  switch (currency) {
    case 'USD':
      return 'US\$';
    case 'EUR':
      return '€';
    case 'ARS':
    default:
      return '\$';
  }
}

/// Amount only (no currency), with grouping and fraction per locale.
String formatLocalizedAmount(double amount, Locale locale) {
  return NumberFormat.decimalPatternDigits(
    locale: moneyLocaleTag(locale),
    decimalDigits: 2,
  ).format(amount);
}

String formatMoney(double amount, String currency, Locale locale) {
  return '${currencySymbol(currency)} ${formatLocalizedAmount(amount, locale)}';
}

List<String> formatTotalsByCurrency(
  Map<String, double> totals,
  Locale locale,
) {
  final keys = totals.keys.toList()..sort();
  return keys
      .where((currency) => (totals[currency] ?? 0) > 0)
      .map((currency) => formatMoney(totals[currency] ?? 0, currency, locale))
      .toList();
}

/// Parses user-entered money strings for the active UI locale.
///
/// Spanish (LatAm): `.` thousands, `,` decimal. English: `,` thousands, `.` decimal.
double? parseMoneyInput(String raw, Locale locale) {
  var s = raw.trim();
  if (s.isEmpty) {
    return null;
  }
  s = s.replaceAll(RegExp(r'US\$', caseSensitive: false), '');
  s = s.replaceAll('€', '');
  s = s.replaceAll('\$', '');
  s = s.trim();
  if (locale.languageCode == 'en') {
    s = s.replaceAll(',', '');
  } else {
    s = s.replaceAll('.', '').replaceAll(',', '.');
  }
  return double.tryParse(s);
}
