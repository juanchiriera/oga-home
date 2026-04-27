import 'package:craftr_mobile/features/home/home_dashboard_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('familyDisplayNameFromFirestoreFields', () {
    test('returns trimmed name when non-empty', () {
      expect(
        familyDisplayNameFromFirestoreFields(
          {'name': '  Casa central  '},
          '(sin nombre)',
        ),
        'Casa central',
      );
    });

    test('returns unnamed label when name missing or blank', () {
      const unnamed = '(sin nombre)';
      expect(familyDisplayNameFromFirestoreFields(null, unnamed), unnamed);
      expect(familyDisplayNameFromFirestoreFields({}, unnamed), unnamed);
      expect(
        familyDisplayNameFromFirestoreFields({'name': ''}, unnamed),
        unnamed,
      );
      expect(
        familyDisplayNameFromFirestoreFields({'name': '   '}, unnamed),
        unnamed,
      );
    });
  });
}
