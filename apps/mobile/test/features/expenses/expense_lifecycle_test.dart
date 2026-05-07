import 'package:oga/features/expenses/expense_lifecycle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ExpenseLifecycle', () {
    test('usa pending_card_cycle para tarjeta de crédito', () {
      expect(
        ExpenseLifecycle.statusForPaymentMethodType(PaymentMethodTypes.creditCard),
        ExpenseLifecycle.pendingCardCycle,
      );
    });

    test('usa confirmed para medios no tarjeta', () {
      expect(
        ExpenseLifecycle.statusForPaymentMethodType(PaymentMethodTypes.cash),
        ExpenseLifecycle.confirmed,
      );
      expect(
        ExpenseLifecycle.statusForPaymentMethodType(PaymentMethodTypes.bank),
        ExpenseLifecycle.confirmed,
      );
    });

    test('excluye cancelados y pendientes del mensual efectivo', () {
      expect(
        ExpenseLifecycle.countsTowardEffectiveMonthly({
          'status': ExpenseLifecycle.cancelled,
        }),
        isFalse,
      );
      expect(
        ExpenseLifecycle.countsTowardEffectiveMonthly({
          'status': ExpenseLifecycle.pendingCardCycle,
        }),
        isFalse,
      );
      expect(
        ExpenseLifecycle.countsTowardEffectiveMonthly({
          'status': ExpenseLifecycle.confirmed,
        }),
        isTrue,
      );
    });
  });

  group('PaymentMethodTypes', () {
    test('incluye los tipos soportados y etiqueta unknown sin modificar', () {
      expect(PaymentMethodTypes.values, contains(PaymentMethodTypes.creditCard));
      expect(PaymentMethodTypes.label('custom_type'), 'custom_type');
    });

    test('asigna sortRank con efectivo/débito antes de tarjeta', () {
      expect(
        PaymentMethodTypes.sortRank(PaymentMethodTypes.cash) <
            PaymentMethodTypes.sortRank(PaymentMethodTypes.creditCard),
        isTrue,
      );
      expect(
        PaymentMethodTypes.sortRank(PaymentMethodTypes.debit) <
            PaymentMethodTypes.sortRank(PaymentMethodTypes.creditCard),
        isTrue,
      );
      expect(
        PaymentMethodTypes.sortRank(PaymentMethodTypes.bank) <
            PaymentMethodTypes.sortRank(PaymentMethodTypes.creditCard),
        isTrue,
      );
      expect(
        PaymentMethodTypes.sortRank(PaymentMethodTypes.creditCard),
        greaterThan(PaymentMethodTypes.sortRank(PaymentMethodTypes.other)),
      );
      expect(
        PaymentMethodTypes.sortRank('unknown'),
        PaymentMethodTypes.sortRank(PaymentMethodTypes.other),
      );
    });
  });

  group('sortPaymentMethods', () {
    final methods = [
      {'id': 'a', 'type': PaymentMethodTypes.creditCard, 'name': 'Visa hogar'},
      {'id': 'b', 'type': PaymentMethodTypes.cash, 'name': 'Billetera'},
      {'id': 'c', 'type': PaymentMethodTypes.debit, 'name': 'Débito BBVA'},
      {
        'id': 'd',
        'type': PaymentMethodTypes.creditCard,
        'name': 'Mastercard Black',
      },
      {'id': 'e', 'type': PaymentMethodTypes.bank, 'name': 'Mercado Pago'},
      {'id': 'f', 'type': PaymentMethodTypes.cash, 'name': 'efectivo viaje'},
      {'id': 'g', 'type': PaymentMethodTypes.other, 'name': 'Vouchers'},
    ];

    test('coloca débito y efectivo arriba y tarjetas al final', () {
      final ordered = sortPaymentMethods<Map<String, String>>(
        methods,
        typeOf: (m) => m['type']!,
        nameOf: (m) => m['name']!,
      );
      final ids = ordered.map((m) => m['id']).toList();
      expect(ids, ['b', 'f', 'c', 'e', 'g', 'd', 'a']);
    });

    test('respeta tipos desconocidos junto a "otro"', () {
      final ordered = sortPaymentMethods<Map<String, String>>(
        [
          {'id': '1', 'type': 'wallet', 'name': 'Naranja X'},
          {'id': '2', 'type': PaymentMethodTypes.other, 'name': 'Vouchers'},
          {
            'id': '3',
            'type': PaymentMethodTypes.creditCard,
            'name': 'Visa Gold',
          },
          {'id': '4', 'type': PaymentMethodTypes.cash, 'name': 'Caja chica'},
        ],
        typeOf: (m) => m['type']!,
        nameOf: (m) => m['name']!,
      );
      expect(ordered.map((m) => m['id']).toList(), ['4', '1', '2', '3']);
    });

    test('preserva la lista original (no muta entrada)', () {
      final input = [
        {'id': 'x', 'type': PaymentMethodTypes.creditCard, 'name': 'Card'},
        {'id': 'y', 'type': PaymentMethodTypes.cash, 'name': 'Cash'},
      ];
      final inputCopy = List<Map<String, String>>.from(input);
      sortPaymentMethods<Map<String, String>>(
        input,
        typeOf: (m) => m['type']!,
        nameOf: (m) => m['name']!,
      );
      expect(input, inputCopy);
    });
  });

  group('comparePaymentMethods', () {
    test('desempate alfabético dentro del mismo rank', () {
      final result = comparePaymentMethods(
        typeA: PaymentMethodTypes.cash,
        nameA: 'Zelda',
        typeB: PaymentMethodTypes.cash,
        nameB: 'Anita',
      );
      expect(result, greaterThan(0));
    });

    test('rank inferior gana al rank superior aunque el nombre sea posterior', () {
      final result = comparePaymentMethods(
        typeA: PaymentMethodTypes.creditCard,
        nameA: 'Aaa',
        typeB: PaymentMethodTypes.cash,
        nameB: 'Zzz',
      );
      expect(result, greaterThan(0));
    });
  });
}
