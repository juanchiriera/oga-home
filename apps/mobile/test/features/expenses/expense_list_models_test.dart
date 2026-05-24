import 'package:oga/features/expenses/expense_list_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatExpenseListDate', () {
    expect(formatExpenseListDate(DateTime(2026, 3, 7)), '07/03/2026');
  });
}
