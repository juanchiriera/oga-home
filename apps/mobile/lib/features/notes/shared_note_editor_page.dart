import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:craftr_mobile/design_system/design_system.dart';
import 'package:craftr_mobile/features/notes/widgets/note_markdown_content.dart';
import 'package:flutter/material.dart';

/// Full-screen editor for a shared family note (aligned with recipe detail flow).
///
/// Controllers live in [State] so text survives device rotation.
class SharedNoteEditorPage extends StatefulWidget {
  const SharedNoteEditorPage({
    super.key,
    required this.familyId,
    this.noteRef,
    this.initialTitle = '',
    this.initialContent = '',
  });

  final String familyId;
  final DocumentReference<Map<String, dynamic>>? noteRef;
  final String initialTitle;
  final String initialContent;

  @override
  State<SharedNoteEditorPage> createState() => _SharedNoteEditorPageState();
}

class _SharedNoteEditorPageState extends State<SharedNoteEditorPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _contentController = TextEditingController(text: widget.initialContent);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final content = _contentController.text;
    if (title.isEmpty || content.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Necesitás un título y contenido para guardar.'),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'title': title,
        'content': content,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (widget.noteRef == null) {
        await FirebaseFirestore.instance
            .collection('families')
            .doc(widget.familyId)
            .collection('sharedNotes')
            .add({
              ...payload,
              'createdAt': FieldValue.serverTimestamp(),
            });
      } else {
        await widget.noteRef!.update(payload);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo guardar: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final appTitle = widget.noteRef == null ? 'Nueva nota' : 'Editar nota';

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: sanctuaryAppBar(
        context,
        title: appTitle,
        actions: [
          IconButton(
            tooltip: 'Guardar',
            onPressed: _saving ? null : _save,
            icon: _saving
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.primary,
                    ),
                  )
                : const Icon(Icons.save_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          24,
          MediaQuery.paddingOf(context).top + kToolbarHeight + 8,
          24,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          TextField(
            controller: _titleController,
            autofocus: widget.noteRef == null && widget.initialTitle.isEmpty,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Título',
              border: OutlineInputBorder(),
            ),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Contenido',
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _contentController,
            minLines: 14,
            maxLines: 24,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Markdown soportado: listas, negritas, links…',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 20),
          ExpansionTile(
            title: Text(
              'Vista previa',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              'Así se verá la nota al leerla',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: AnimatedBuilder(
                  animation: Listenable.merge([
                    _titleController,
                    _contentController,
                  ]),
                  builder: (context, _) {
                    return NoteMarkdownContent(
                      text: _contentController.text,
                      textStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurface,
                        height: 1.45,
                      ),
                      linkColor: scheme.primary,
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
