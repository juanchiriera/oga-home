import 'dart:async';

import 'package:flutter/material.dart';

/// Compact formatting shortcuts for shared-note Markdown ([SharedNoteEditorPage]).
class NoteMarkdownEditorToolbar extends StatelessWidget {
  const NoteMarkdownEditorToolbar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.resolveSelection,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final TextSelection Function() resolveSelection;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    void apply(void Function(TextSelection sel) fn) {
      fn(resolveSelection());
    }

    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          children: [
            _ToolbarIcon(
              tooltip: 'Negrita',
              icon: Icons.format_bold_rounded,
              onPressed: () => apply(
                (sel) => _wrapMarkdown(controller, focusNode, sel, '**', '**'),
              ),
            ),
            _ToolbarIcon(
              tooltip: 'Cursiva',
              icon: Icons.format_italic_rounded,
              onPressed: () => apply(
                (sel) => _wrapMarkdown(controller, focusNode, sel, '*', '*'),
              ),
            ),
            _ToolbarIcon(
              tooltip: 'Código',
              icon: Icons.code_rounded,
              onPressed: () => apply(
                (sel) => _wrapMarkdown(controller, focusNode, sel, '`', '`'),
              ),
            ),
            _ToolbarIcon(
              tooltip: 'Título',
              icon: Icons.title_rounded,
              onPressed: () => apply(
                (sel) => _toggleLinePrefix(
                  controller,
                  focusNode,
                  sel,
                  '## ',
                  trimLine: true,
                ),
              ),
            ),
            _ToolbarIcon(
              tooltip: 'Lista',
              icon: Icons.format_list_bulleted_rounded,
              onPressed: () => apply(
                (sel) => _toggleLinePrefix(
                  controller,
                  focusNode,
                  sel,
                  '- ',
                  trimLine: false,
                ),
              ),
            ),
            _ToolbarIcon(
              tooltip: 'Enlace',
              icon: Icons.link_rounded,
              onPressed: () => unawaited(_insertLink(context)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _insertLink(BuildContext context) async {
    final sel = resolveSelection();
    final text = controller.text;
    final start = sel.start.clamp(0, text.length);
    final end = sel.end.clamp(0, text.length);
    final lo = start <= end ? start : end;
    final hi = start <= end ? end : start;
    final selected = lo == hi ? '' : text.substring(lo, hi);

    final labelController = TextEditingController(
      text: selected.isEmpty ? 'texto' : selected,
    );
    final urlController = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Insertar enlace'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: labelController,
              decoration: const InputDecoration(labelText: 'Texto visible'),
              autofocus: selected.isEmpty,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(labelText: 'URL (https://…)'),
              keyboardType: TextInputType.url,
              autofocus: selected.isNotEmpty,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Insertar'),
          ),
        ],
      ),
    );

    if (ok != true || !context.mounted) {
      labelController.dispose();
      urlController.dispose();
      return;
    }

    final label = labelController.text.trim().isEmpty
        ? 'texto'
        : labelController.text.trim();
    final url = urlController.text.trim();
    labelController.dispose();
    urlController.dispose();

    if (url.isEmpty) {
      return;
    }

    final wrapped = '[$label]($url)';
    final newText = text.replaceRange(lo, hi, wrapped);
    controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: lo + wrapped.length),
    );
    focusNode.requestFocus();
  }
}

class _ToolbarIcon extends StatelessWidget {
  const _ToolbarIcon({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      padding: EdgeInsets.zero,
      onPressed: onPressed,
      icon: Icon(icon, size: 22),
    );
  }
}

void _wrapMarkdown(
  TextEditingController controller,
  FocusNode focusNode,
  TextSelection selection,
  String left,
  String right,
) {
  final text = controller.text;
  var start = selection.start.clamp(0, text.length);
  var end = selection.end.clamp(0, text.length);
  if (end < start) {
    final t = start;
    start = end;
    end = t;
  }
  final selected = text.substring(start, end);
  final insert = selected.isEmpty ? '$left$right' : '$left$selected$right';
  final newText = text.replaceRange(start, end, insert);
  final cursor = selected.isEmpty ? start + left.length : start + insert.length;
  controller.value = TextEditingValue(
    text: newText,
    selection: TextSelection.collapsed(offset: cursor.clamp(0, newText.length)),
  );
  focusNode.requestFocus();
}

void _toggleLinePrefix(
  TextEditingController controller,
  FocusNode focusNode,
  TextSelection selection,
  String prefix, {
  required bool trimLine,
}) {
  final text = controller.text;
  final pos = selection.extentOffset.clamp(0, text.length);
  var lineStart = pos;
  while (lineStart > 0 && text[lineStart - 1] != '\n') {
    lineStart--;
  }
  final nl = text.indexOf('\n', lineStart);
  final lineEnd = nl == -1 ? text.length : nl;
  var line = text.substring(lineStart, lineEnd);
  if (trimLine) {
    line = line.trimLeft();
  }

  String newLine;
  if (line.startsWith(prefix)) {
    newLine = line.substring(prefix.length);
  } else {
    newLine = '$prefix$line';
  }

  final newText = text.replaceRange(lineStart, lineEnd, newLine);
  final delta = newLine.length - (lineEnd - lineStart);
  final newPos = (pos + delta).clamp(0, newText.length);
  controller.value = TextEditingValue(
    text: newText,
    selection: TextSelection.collapsed(offset: newPos),
  );
  focusNode.requestFocus();
}
