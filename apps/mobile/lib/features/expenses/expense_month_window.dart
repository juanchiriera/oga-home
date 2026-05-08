class ExpenseMonthWindow {
  const ExpenseMonthWindow({
    required this.startInclusive,
    required this.endExclusive,
  });

  final DateTime startInclusive;
  final DateTime endExclusive;

  bool contains(DateTime? value) {
    if (value == null) {
      return false;
    }
    return !value.isBefore(startInclusive) && value.isBefore(endExclusive);
  }
}

ExpenseMonthWindow expenseMonthWindowForLocal(DateTime now) {
  return expenseMonthWindowForMonth(now.year, now.month);
}

ExpenseMonthWindow expenseMonthWindowForMonth(int year, int month) {
  final start = DateTime(year, month, 1);
  final end = DateTime(year, month + 1, 1);
  return ExpenseMonthWindow(startInclusive: start, endExclusive: end);
}
