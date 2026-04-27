import 'package:craftr_mobile/features/stock/stock_list_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StockListPage filter logic', () {
    test('default filter incluye items en stock y faltantes', () {
      expect(
        StockListPage.matchesFilter(
          StockLevel.hay,
          filter: StockViewFilter.all,
          includeLow: false,
        ),
        isTrue,
      );
      expect(
        StockListPage.matchesFilter(
          StockLevel.out,
          filter: StockViewFilter.all,
          includeLow: false,
        ),
        isTrue,
      );
      expect(
        StockListPage.matchesFilter(
          StockLevel.low,
          filter: StockViewFilter.all,
          includeLow: false,
        ),
        isTrue,
      );
    });

    test('falta comprar respeta includeLow', () {
      expect(
        StockListPage.matchesFilter(
          StockLevel.low,
          filter: StockViewFilter.missing,
          includeLow: false,
        ),
        isFalse,
      );
      expect(
        StockListPage.matchesFilter(
          StockLevel.low,
          filter: StockViewFilter.missing,
          includeLow: true,
        ),
        isTrue,
      );
    });

    test('conteos son consistentes al alternar filtros', () {
      const levels = [StockLevel.hay, StockLevel.low, StockLevel.out];

      final withoutLow = StockListPage.buildFilterCounts(
        levels,
        includeLow: false,
      );
      expect(withoutLow[StockViewFilter.all], 3);
      expect(withoutLow[StockViewFilter.inStock], 2);
      expect(withoutLow[StockViewFilter.missing], 1);

      final withLow = StockListPage.buildFilterCounts(levels, includeLow: true);
      expect(withLow[StockViewFilter.all], 3);
      expect(withLow[StockViewFilter.inStock], 2);
      expect(withLow[StockViewFilter.missing], 2);
    });
  });
}
