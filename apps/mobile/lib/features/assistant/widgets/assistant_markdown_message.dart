import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';

final RegExp _markdownHints = RegExp(
  r'(^|\s)([#>*`~\-\+]|(\d+\.))\s|(\*\*|__|`|\[.+?\]\(.+?\)|\|)',
  multiLine: true,
);

/// Detects if a message likely contains markdown syntax.
bool looksLikeMarkdown(String text) => _markdownHints.hasMatch(text);

/// Escapes raw HTML so only markdown syntax is rendered.
String sanitizeMarkdownInput(String input) {
  return input
      .replaceAll('\u0000', '')
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;');
}

/// Accepts only safe URI schemes for tappable links.
Uri? safeLinkUri(String? href) {
  if (href == null || href.trim().isEmpty) return null;
  final uri = Uri.tryParse(href.trim());
  if (uri == null || !uri.hasScheme) return null;
  final scheme = uri.scheme.toLowerCase();
  if (scheme == 'http' || scheme == 'https' || scheme == 'mailto') {
    return uri;
  }
  return null;
}

class AssistantMarkdownMessage extends StatelessWidget {
  const AssistantMarkdownMessage({
    super.key,
    required this.text,
    required this.textColor,
  });

  final String text;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final normalized = text.trimRight();
    if (normalized.isEmpty) return const SizedBox.shrink();
    if (!looksLikeMarkdown(normalized)) {
      return Text(
        normalized,
        style: Theme.of(
          context,
        ).textTheme.bodyMedium?.copyWith(color: textColor),
      );
    }

    return MarkdownBody(
      data: sanitizeMarkdownInput(normalized),
      selectable: true,
      extensionSet: md.ExtensionSet.gitHubFlavored,
      softLineBreak: true,
      styleSheet: _styleSheet(context, textColor),
      onTapLink: (label, href, title) => _openSafeLink(context, href),
    );
  }

  MarkdownStyleSheet _styleSheet(BuildContext context, Color textColor) {
    final textTheme = Theme.of(context).textTheme;
    return MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
      p: textTheme.bodyMedium?.copyWith(color: textColor),
      h1: textTheme.titleLarge?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w800,
      ),
      h2: textTheme.titleMedium?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w700,
      ),
      h3: textTheme.titleSmall?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w700,
      ),
      listBullet: textTheme.bodyMedium?.copyWith(color: textColor),
      strong: textTheme.bodyMedium?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w700,
      ),
      em: textTheme.bodyMedium?.copyWith(
        color: textColor,
        fontStyle: FontStyle.italic,
      ),
      code: textTheme.bodySmall?.copyWith(
        color: textColor,
        fontFamily: 'monospace',
      ),
      codeblockDecoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(10),
      ),
      codeblockPadding: const EdgeInsets.all(12),
      blockSpacing: 10,
      a: textTheme.bodyMedium?.copyWith(
        color: Theme.of(context).colorScheme.primary,
        decoration: TextDecoration.underline,
      ),
    );
  }

  void _openSafeLink(BuildContext context, String? href) {
    final uri = safeLinkUri(href);
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
