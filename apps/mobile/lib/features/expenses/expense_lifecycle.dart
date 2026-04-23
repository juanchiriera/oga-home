/// Estados de gasto alineados con docs/PRODUCTO_Y_BACKLOG.md §7.3.3.
abstract final class ExpenseLifecycle {
  static const confirmed = 'confirmed';
  static const pendingCardCycle = 'pending_card_cycle';
  static const cancelled = 'cancelled';

  static bool countsTowardEffectiveMonthly(Map<String, dynamic> data) {
    final s = data['status'] as String?;
    if (s == cancelled) {
      return false;
    }
    if (s == pendingCardCycle) {
      return false;
    }
    return true;
  }

  static String statusForPaymentMethodType(String type) {
    return type == 'credit_card' ? pendingCardCycle : confirmed;
  }
}

abstract final class PaymentMethodTypes {
  static const cash = 'cash';
  static const debit = 'debit';
  static const bank = 'bank';
  static const creditCard = 'credit_card';
  static const other = 'other';

  static const values = [cash, debit, bank, creditCard, other];

  static String label(String type) {
    switch (type) {
      case cash:
        return 'Efectivo';
      case debit:
        return 'Débito';
      case bank:
        return 'Transferencia / banco';
      case creditCard:
        return 'Tarjeta de crédito';
      case other:
        return 'Otro';
      default:
        return type;
    }
  }
}
