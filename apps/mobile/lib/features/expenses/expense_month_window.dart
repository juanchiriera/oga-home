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
  final start = DateTime(now.year, now.month, 1);
  final end = DateTime(now.year, now.month + 1, 1);
  return ExpenseMonthWindow(startInclusive: start, endExclusive: end);
}
