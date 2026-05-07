import 'package:oga/features/notes/widgets/note_markdown_content.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sanitizeNoteMarkdownInput', () {
    test('escapes html and preserves markdown markers', () {
      const input = '<script>alert(1)</script> **bold**';
      final output = sanitizeNoteMarkdownInput(input);

      expect(output, '&lt;script&gt;alert(1)&lt;/script&gt; **bold**');
    });

    test('escapes ampersands before html brackets', () {
      const input = 'A & B < C';
      final output = sanitizeNoteMarkdownInput(input);

      expect(output, 'A &amp; B &lt; C');
    });
  });

  group('safeNoteLinkUri', () {
    test('allows safe schemes', () {
      expect(
        safeNoteLinkUri('https://example.com/path')?.toString(),
        'https://example.com/path',
      );
      expect(safeNoteLinkUri('mailto:help@example.com')?.scheme, 'mailto');
    });

    test('rejects unsafe schemes or invalid values', () {
      expect(safeNoteLinkUri('javascript:alert(1)'), isNull);
      expect(safeNoteLinkUri('data:text/plain,hello'), isNull);
      expect(safeNoteLinkUri('/relative/path'), isNull);
      expect(safeNoteLinkUri(''), isNull);
      expect(safeNoteLinkUri(null), isNull);
    });
  });

  group('truncateNoteContentForPreview', () {
    test('returns short text unchanged', () {
      expect(truncateNoteContentForPreview('hola'), 'hola');
      expect(truncateNoteContentForPreview(''), '');
    });

    test('truncates long ASCII with ellipsis', () {
      final long = 'x' * (kSharedNotePreviewMaxChars + 50);
      final out = truncateNoteContentForPreview(long);
      expect(out.endsWith('…'), isTrue);
      expect(out.length, lessThan(long.length));
    });

    test('preserves whole emoji when truncating after ascii prefix', () {
      const emoji = '😀';
      final s = '${'a' * 10}$emoji$emoji';
      final out = truncateNoteContentForPreview(s, maxChars: 11);
      expect(out, 'aaaaaaaaaa😀…');
      expect(out.contains('\uFFFD'), isFalse);
    });
  });

  group('NoteMarkdownContent', () {
    testWidgets('renders plain text through MarkdownBody', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NoteMarkdownContent(
              text: 'Texto plano sin formato',
              textStyle: TextStyle(fontSize: 16),
              linkColor: Colors.blue,
            ),
          ),
        ),
      );

      expect(find.byType(MarkdownBody), findsOneWidget);
    });

    testWidgets('renders markdown content using markdown widget', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NoteMarkdownContent(
              text: '# Titulo\n\n- item 1\n- item 2',
              textStyle: TextStyle(fontSize: 16),
              linkColor: Colors.blue,
            ),
          ),
        ),
      );

      expect(find.byType(MarkdownBody), findsOneWidget);
    });
  });
}
