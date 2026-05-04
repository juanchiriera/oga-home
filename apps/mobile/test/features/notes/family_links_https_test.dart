import 'package:oga/features/notes/family_links_page.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isFamilyLinksHttpsUrl', () {
    test('accepts https with host', () {
      expect(isFamilyLinksHttpsUrl('https://example.com/path'), isTrue);
      expect(isFamilyLinksHttpsUrl('HTTPS://EXAMPLE.COM'), isTrue);
    });

    test('rejects non-https or missing authority', () {
      expect(isFamilyLinksHttpsUrl('http://example.com'), isFalse);
      expect(isFamilyLinksHttpsUrl('javascript:alert(1)'), isFalse);
      expect(isFamilyLinksHttpsUrl('https://'), isFalse);
      expect(isFamilyLinksHttpsUrl(''), isFalse);
    });
  });
}
