import 'package:oga/features/expenses/expense_month_window.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('expenseMonthWindowForLocal', () {
    test('calcula inicio y fin exclusivos del mes actual', () {
      final window = expenseMonthWindowForLocal(DateTime(2026, 4, 27, 18, 15));

      expect(window.startInclusive, DateTime(2026, 4, 1));
      expect(window.endExclusive, DateTime(2026, 5, 1));
    });

    test('maneja correctamente el cambio de diciembre a enero', () {
      final window = expenseMonthWindowForLocal(DateTime(2026, 12, 15));

      expect(window.startInclusive, DateTime(2026, 12, 1));
      expect(window.endExclusive, DateTime(2027, 1, 1));
    });
  });

  group('ExpenseMonthWindow.contains', () {
    final window = ExpenseMonthWindow(
      startInclusive: DateTime(2026, 4, 1),
      endExclusive: DateTime(2026, 5, 1),
    );

    test('incluye el inicio y excluye el fin del mes', () {
      expect(window.contains(DateTime(2026, 4, 1, 0, 0)), isTrue);
      expect(window.contains(DateTime(2026, 4, 30, 23, 59, 59)), isTrue);
      expect(window.contains(DateTime(2026, 5, 1, 0, 0)), isFalse);
    });

    test('retorna false para fechas nulas o fuera del mes', () {
      expect(window.contains(null), isFalse);
      expect(window.contains(DateTime(2026, 3, 31, 23, 59, 59)), isFalse);
    });

    test('sin datos del mes deja la colección vacía', () {
      final records = <DateTime?>[];
      final filtered = records.where(window.contains).toList();

      expect(filtered, isEmpty);
    });
  });
}
