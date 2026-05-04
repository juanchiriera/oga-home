import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:oga/design_system/design_system.dart';
import 'package:oga/features/notes/shared_note_editor_page.dart';
import 'package:oga/features/notes/widgets/note_markdown_content.dart';
import 'package:flutter/material.dart';

/// Pantalla completa de solo lectura para una nota compartida.
class SharedNotePreviewPage extends StatelessWidget {
  const SharedNotePreviewPage({
    super.key,
    required this.familyId,
    required this.noteRef,
    required this.title,
    required this.content,
  });

  final String familyId;
  final DocumentReference<Map<String, dynamic>> noteRef;
  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: sanctuaryAppBar(
        context,
        title: 'Vista previa',
        actions: [
          IconButton(
            tooltip: 'Editar',
            onPressed: () async {
              final saved = await Navigator.of(context).push<bool>(
                MaterialPageRoute<bool>(
                  builder: (ctx) => SharedNoteEditorPage(
                    familyId: familyId,
                    noteRef: noteRef,
                    initialTitle: title,
                    initialContent: content,
                  ),
                ),
              );
              if (!context.mounted) {
                return;
              }
              if (saved == true) {
                Navigator.of(context).pop();
              }
            },
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: Scrollbar(
        thumbVisibility: true,
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                24,
                MediaQuery.paddingOf(context).top + kSanctuaryAppBarToolbarHeight + 8,
                24,
                24 + MediaQuery.paddingOf(context).bottom,
              ),
              sliver: SliverToBoxAdapter(
                child: Semantics(
                  container: true,
                  label: 'Contenido de la nota',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      NoteMarkdownContent(
                        text: content,
                        textStyle: theme.textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurface,
                          height: 1.45,
                        ),
                        linkColor: scheme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
