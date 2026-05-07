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

  /// Display rank used to order payment methods in the UI (Trello #98):
  /// efectivo/débito/banco aparecen primero y la tarjeta de crédito al final.
  /// Tipos desconocidos quedan justo encima de las tarjetas, junto a "otro".
  static int sortRank(String type) {
    switch (type) {
      case cash:
        return 0;
      case debit:
        return 1;
      case bank:
        return 2;
      case other:
        return 3;
      case creditCard:
        return 4;
      default:
        return 3;
    }
  }
}

/// Ordena dos métodos de pago aplicando primero el rank por tipo
/// (`PaymentMethodTypes.sortRank`) y desempatando alfabéticamente por nombre.
int comparePaymentMethods({
  required String typeA,
  required String nameA,
  required String typeB,
  required String nameB,
}) {
  final rankA = PaymentMethodTypes.sortRank(typeA);
  final rankB = PaymentMethodTypes.sortRank(typeB);
  if (rankA != rankB) {
    return rankA.compareTo(rankB);
  }
  return nameA.toLowerCase().compareTo(nameB.toLowerCase());
}

/// Devuelve una nueva lista con los métodos de pago ordenados según
/// [comparePaymentMethods]. Permite usar la misma regla con cualquier
/// representación (snapshots de Firestore, mapas en memoria, etc.).
List<T> sortPaymentMethods<T>(
  Iterable<T> items, {
  required String Function(T item) typeOf,
  required String Function(T item) nameOf,
}) {
  final sorted = items.toList(growable: false);
  sorted.sort(
    (a, b) => comparePaymentMethods(
      typeA: typeOf(a),
      nameA: nameOf(a),
      typeB: typeOf(b),
      nameB: nameOf(b),
    ),
  );
  return sorted;
}
