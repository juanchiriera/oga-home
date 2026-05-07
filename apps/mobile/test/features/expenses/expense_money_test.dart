import 'package:flutter/widgets.dart';
import 'package:oga/features/expenses/expense_money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normaliza moneda con fallback ante valores vacíos o inválidos', () {
    expect(normalizeCurrency(null, fallback: 'ARS'), 'ARS');
    expect(normalizeCurrency(' ', fallback: 'ARS'), 'ARS');
    expect(normalizeCurrency('usd', fallback: 'ARS'), 'USD');
    expect(normalizeCurrency('clp', fallback: 'ARS'), 'ARS');
  });

  test('suma totales por moneda y omite montos no positivos', () {
    final totals = <String, double>{};
    addToCurrencyTotals(
      totals,
      {'amount': 12.5, 'currency': 'USD'},
      fallbackCurrency: 'ARS',
    );
    addToCurrencyTotals(
      totals,
      {'amount': 7, 'currency': 'usd'},
      fallbackCurrency: 'ARS',
    );
    addToCurrencyTotals(
      totals,
      {'amount': 0, 'currency': 'EUR'},
      fallbackCurrency: 'ARS',
    );
    addToCurrencyTotals(
      totals,
      {'amount': -4, 'currency': 'EUR'},
      fallbackCurrency: 'ARS',
    );

    expect(totals, {'USD': 19.5});
  });

  test('formatea y ordena monedas con símbolos correctos (es_AR)', () {
    final es = const Locale('es', 'AR');
    final labels = formatTotalsByCurrency({
      'USD': 9,
      'ARS': 12.25,
      'EUR': 3.5,
      'CLP': 100, // inválida en dominio, queda como fallback de formato ($)
      'ZERO': 0,
    }, es);

    expect(
      labels,
      [
        '\$ 12,25',
        '\$ 100,00',
        '€ 3,50',
        'US\$ 9,00',
      ],
    );
  });

  test('formatMoney un millón: es milésimos con punto y decimales con coma', () {
    expect(
      formatMoney(1000000, 'ARS', const Locale('es', 'AR')),
      '\$ 1.000.000,00',
    );
  });

  test('formatMoney un millón: en miles con coma y decimales con punto', () {
    expect(
      formatMoney(1000000, 'ARS', const Locale('en', 'US')),
      '\$ 1,000,000.00',
    );
  });

  test('parseMoneyInput respeta locale español', () {
    expect(
      parseMoneyInput('1.000.000,50', const Locale('es', 'AR')),
      1000000.5,
    );
    expect(parseMoneyInput('1000,5', const Locale('es', 'AR')), 1000.5);
    expect(parseMoneyInput(r'US$ 10,25', const Locale('es', 'AR')), 10.25);
  });

  test('parseMoneyInput respeta locale inglés', () {
    expect(
      parseMoneyInput('1,000,000.50', const Locale('en', 'US')),
      1000000.5,
    );
    expect(parseMoneyInput('1000.5', const Locale('en', 'US')), 1000.5);
  });
}
