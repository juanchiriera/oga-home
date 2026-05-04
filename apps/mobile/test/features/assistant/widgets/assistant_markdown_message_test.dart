import 'package:oga/features/assistant/widgets/assistant_markdown_message.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sanitizeMarkdownInput', () {
    test('escapes html and preserves markdown markers', () {
      const input = '<script>alert(1)</script> **bold**';
      final output = sanitizeMarkdownInput(input);

      expect(output, '&lt;script&gt;alert(1)&lt;/script&gt; **bold**');
    });

    test('escapes ampersands before html brackets', () {
      const input = 'A & B < C';
      final output = sanitizeMarkdownInput(input);

      expect(output, 'A &amp; B &lt; C');
    });
  });

  group('looksLikeMarkdown', () {
    test('detects headings and links', () {
      expect(looksLikeMarkdown('# Titulo'), isTrue);
      expect(looksLikeMarkdown('[docs](https://example.com)'), isTrue);
    });

    test('returns false for plain text', () {
      expect(looksLikeMarkdown('Mensaje simple sin formato'), isFalse);
    });
  });

  group('safeLinkUri', () {
    test('allows safe schemes', () {
      expect(
        safeLinkUri('https://example.com/path')?.toString(),
        'https://example.com/path',
      );
      expect(safeLinkUri('mailto:help@example.com')?.scheme, 'mailto');
    });

    test('rejects unsafe schemes or invalid values', () {
      expect(safeLinkUri('javascript:alert(1)'), isNull);
      expect(safeLinkUri('data:text/plain,hello'), isNull);
      expect(safeLinkUri('/relative/path'), isNull);
      expect(safeLinkUri(''), isNull);
      expect(safeLinkUri(null), isNull);
    });
  });
}
