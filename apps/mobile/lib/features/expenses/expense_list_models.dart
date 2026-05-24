import 'package:cloud_firestore/cloud_firestore.dart';

String formatExpenseListDate(DateTime value) {
  final dd = value.day.toString().padLeft(2, '0');
  final mm = value.month.toString().padLeft(2, '0');
  final yyyy = value.year.toString();
  return '$dd/$mm/$yyyy';
}

/// Immutable snapshot of one expense row for in-memory lists and navigation.
class ExpenseListEntry {
  ExpenseListEntry({required this.id, required Map<String, dynamic> data})
    : data = Map<String, dynamic>.from(data);

  factory ExpenseListEntry.fromQueryDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) => ExpenseListEntry(id: doc.id, data: doc.data());

  final String id;
  final Map<String, dynamic> data;

  DateTime? get occurredAt => (data['occurredAt'] as Timestamp?)?.toDate();

  /// Replaces fields (e.g. after a successful write). [data] is copied.
  ExpenseListEntry copyWithData(Map<String, dynamic> patch) {
    final merged = Map<String, dynamic>.from(data);
    merged.addAll(patch);
    return ExpenseListEntry(id: id, data: merged);
  }
}
