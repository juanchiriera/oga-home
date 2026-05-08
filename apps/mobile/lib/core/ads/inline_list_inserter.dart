List<T> withInlineInsertions<T>({
  required List<T> items,
  required Map<int, T Function()> insertionsAfterIndex,
}) {
  if (items.isEmpty || insertionsAfterIndex.isEmpty) {
    return List<T>.from(items);
  }
  final result = <T>[];
  for (var i = 0; i < items.length; i++) {
    result.add(items[i]);
    final builder = insertionsAfterIndex[i];
    if (builder != null) {
      result.add(builder());
    }
  }
  return result;
}
