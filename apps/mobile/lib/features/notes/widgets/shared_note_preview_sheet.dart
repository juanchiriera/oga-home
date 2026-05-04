import 'package:oga/features/notes/widgets/note_markdown_content.dart';
import 'package:flutter/material.dart';

/// Floating preview: tap outside, drag down, close icon, or system back dismiss.
Future<void> showSharedNotePreviewSheet(
  BuildContext context, {
  required String title,
  required String content,
  required VoidCallback onOpenFullDetail,
}) {
  final scheme = Theme.of(context).colorScheme;
  final textTheme = Theme.of(context).textTheme;
  final excerpt = truncateNoteContentForPreview(content);

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      final maxH = MediaQuery.sizeOf(ctx).height * 0.88;
      return PopScope(
        canPop: true,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxH),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar vista previa',
                      onPressed: () => Navigator.of(ctx).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Vista previa',
                  style: textTheme.labelLarge?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      child: Semantics(
                        container: true,
                        label: 'Contenido de la nota',
                        child: NoteMarkdownContent(
                          text: excerpt,
                          textStyle: textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurface,
                            height: 1.45,
                          ),
                          linkColor: scheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    onOpenFullDetail();
                  },
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('Abrir detalle completo'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
