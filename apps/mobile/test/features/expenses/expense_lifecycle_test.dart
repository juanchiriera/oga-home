import 'package:craftr_mobile/features/expenses/expense_lifecycle.dart';
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
  });
}
