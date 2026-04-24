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

String formatMoney(double amount, String currency) {
  final fixed = amount.toStringAsFixed(2);
  return '${currencySymbol(currency)}$fixed';
}

List<String> formatTotalsByCurrency(Map<String, double> totals) {
  final keys = totals.keys.toList()..sort();
  return keys
      .where((currency) => (totals[currency] ?? 0) > 0)
      .map((currency) => formatMoney(totals[currency] ?? 0, currency))
      .toList();
}
