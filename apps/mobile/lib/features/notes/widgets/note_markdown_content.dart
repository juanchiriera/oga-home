import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

final RegExp _markdownHints = RegExp(
  r'(^|\s)([#>*`~\-\+]|(\d+\.))\s|(\*\*|__|`|\[.+?\]\(.+?\)|\|)',
  multiLine: true,
);

bool looksLikeNoteMarkdown(String text) => _markdownHints.hasMatch(text);

String sanitizeNoteMarkdownInput(String input) {
  return input
      .replaceAll('\u0000', '')
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}

Uri? safeNoteLinkUri(String? href) {
  if (href == null || href.trim().isEmpty) return null;
  final uri = Uri.tryParse(href.trim());
  if (uri == null || !uri.hasScheme) return null;
  final scheme = uri.scheme.toLowerCase();
  if (scheme == 'http' || scheme == 'https' || scheme == 'mailto') {
    return uri;
  }
  return null;
}

/// Max grapheme clusters for floating preview; full content opens in the editor.
const int kSharedNotePreviewMaxChars = 3200;

/// Truncates note body for preview sheets without splitting grapheme clusters.
String truncateNoteContentForPreview(
  String content, {
  int maxChars = kSharedNotePreviewMaxChars,
}) {
  final t = content.trimRight();
  if (t.isEmpty) return t;
  final chars = t.characters;
  if (chars.length <= maxChars) return t;
  return '${chars.take(maxChars).toString().trimRight()}…';
}

class NoteMarkdownContent extends StatelessWidget {
  const NoteMarkdownContent({
    super.key,
    required this.text,
    required this.textStyle,
    required this.linkColor,
  });

  final String text;
  final TextStyle? textStyle;
  final Color linkColor;

  @override
  Widget build(BuildContext context) {
    final normalized = text.trimRight();
    if (normalized.isEmpty) return const SizedBox.shrink();
    if (!looksLikeNoteMarkdown(normalized)) {
      return Text(normalized, style: textStyle);
    }

    return MarkdownBody(
      data: sanitizeNoteMarkdownInput(normalized),
      selectable: true,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      softLineBreak: true,
      styleSheet: _styleSheet(context),
      onTapLink: (label, href, title) => _openSafeLink(context, href),
    );
  }

  MarkdownStyleSheet _styleSheet(BuildContext context) {
    final theme = Theme.of(context);
    final body = textStyle ?? theme.textTheme.bodyMedium;
    return MarkdownStyleSheet.fromTheme(theme).copyWith(
      p: body,
      h1: theme.textTheme.titleLarge?.copyWith(
        color: body?.color,
        fontWeight: FontWeight.w800,
      ),
      h2: theme.textTheme.titleMedium?.copyWith(
        color: body?.color,
        fontWeight: FontWeight.w700,
      ),
      h3: theme.textTheme.titleSmall?.copyWith(
        color: body?.color,
        fontWeight: FontWeight.w700,
      ),
      listBullet: body,
      strong: body?.copyWith(fontWeight: FontWeight.w700),
      em: body?.copyWith(fontStyle: FontStyle.italic),
      code: theme.textTheme.bodySmall?.copyWith(
        color: body?.color,
        fontFamily: 'monospace',
      ),
      codeblockDecoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      codeblockPadding: const EdgeInsets.all(12),
      blockSpacing: 10,
      a: body?.copyWith(color: linkColor, decoration: TextDecoration.underline),
    );
  }

  void _openSafeLink(BuildContext context, String? href) {
    final uri = safeNoteLinkUri(href);
    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Link bloqueado por seguridad.')),
      );
      return;
    }
    unawaited(_launchLink(context, uri));
  }

  Future<void> _launchLink(BuildContext context, Uri uri) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (launched || !context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('No se pudo abrir el link.')));
  }
}
