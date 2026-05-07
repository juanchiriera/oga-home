import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:oga/design_system/design_system.dart';
import 'package:oga/features/notes/widgets/note_markdown_editor_toolbar.dart';
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
  late final FocusNode _contentFocusNode;
  TextSelection _lastContentSelection = const TextSelection.collapsed(
    offset: 0,
  );
  bool _saving = false;

  /// Bordes casi rectos: el tema global usa pastillas (radius 999) poco aptas
  /// para bloques de texto largos.
  InputDecoration _noteEditorFieldDecoration(
    BuildContext context, {
    String? labelText,
    String? hintText,
    bool alignLabelWithHint = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(25);
    final outlineColor = scheme.outline;

    OutlineInputBorder shape({Color? borderColor, double width = 1}) {
      return OutlineInputBorder(
        borderRadius: radius,
        borderSide: BorderSide(
          color: borderColor ?? outlineColor,
          width: width,
        ),
      );
    }

    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      alignLabelWithHint: alignLabelWithHint,
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: shape(),
      enabledBorder: shape(borderColor: outlineColor.withValues(alpha: 0.55)),
      focusedBorder: shape(borderColor: scheme.primary, width: 2),
      errorBorder: shape(borderColor: scheme.error),
      focusedErrorBorder: shape(borderColor: scheme.error, width: 2),
      disabledBorder: shape(borderColor: outlineColor.withValues(alpha: 0.35)),
    );
  }

  void _syncContentSelection() {
    final s = _contentController.selection;
    final len = _contentController.text.length;
    if (s.isValid && s.start <= len && s.end <= len) {
      _lastContentSelection = s;
    }
  }

  TextSelection _resolveContentSelection() {
    final len = _contentController.text.length;
    var s = _contentController.selection;
    if (!s.isValid || s.start > len || s.end > len) {
      s = _lastContentSelection;
    }
    if (!s.isValid || s.start > len || s.end > len) {
      return TextSelection.collapsed(offset: len);
    }
    return s;
  }

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _contentController = TextEditingController(text: widget.initialContent);
    _contentFocusNode = FocusNode();
    _contentController.addListener(_syncContentSelection);
    _syncContentSelection();
  }

  @override
  void dispose() {
    _contentController.removeListener(_syncContentSelection);
    _titleController.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
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
            .add({...payload, 'createdAt': FieldValue.serverTimestamp()});
      } else {
        await widget.noteRef!.update(payload);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
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
          MediaQuery.paddingOf(context).top + kSanctuaryAppBarToolbarHeight + 8,
          24,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          TextField(
            controller: _titleController,
            autofocus: widget.noteRef == null && widget.initialTitle.isEmpty,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Título'),
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
          NoteMarkdownEditorToolbar(
            controller: _contentController,
            focusNode: _contentFocusNode,
            resolveSelection: _resolveContentSelection,
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _contentController,
            focusNode: _contentFocusNode,
            minLines: 14,
            maxLines: 24,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            decoration: _noteEditorFieldDecoration(
              context,
              hintText:
                  'Podés escribir Markdown o usar la barra de arriba (negrita, listas, enlaces…)',
              alignLabelWithHint: true,
            ),
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
          ),
        ],
      ),
    );
  }
}
