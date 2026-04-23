import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:craftr_mobile/features/notes/family_links_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SharedNotesPage extends StatefulWidget {
  const SharedNotesPage({super.key});

  @override
  State<SharedNotesPage> createState() => _SharedNotesPageState();
}

class _SharedNotesPageState extends State<SharedNotesPage> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Sin sesión')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notas compartidas'),
        actions: [
          IconButton(
            tooltip: 'Enlaces útiles',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FamilyLinksPage()),
              );
            },
            icon: const Icon(Icons.link_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openNoteEditor(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva nota'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (context, userSnap) {
          if (!userSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final familyId = userSnap.data!.data()?['activeFamilyId'] as String?;
          if (familyId == null || familyId.isEmpty) {
            return const Center(
              child: Text('Creá o elegí un hogar para gestionar notas.'),
            );
          }

          final notesRef = FirebaseFirestore.instance
              .collection('families')
              .doc(familyId)
              .collection('sharedNotes');

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: notesRef.orderBy('updatedAt', descending: true).snapshots(),
            builder: (context, notesSnap) {
              if (!notesSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = notesSnap.data!.docs;
              final filtered = docs.where((doc) {
                final data = doc.data();
                final title = (data['title'] as String? ?? '').toLowerCase();
                final content = (data['content'] as String? ?? '')
                    .toLowerCase();
                final query = _searchQuery.toLowerCase();
                if (query.isEmpty) {
                  return true;
                }
                return title.contains(query) || content.contains(query);
              }).toList();

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Notas del hogar',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _searchController,
                            onChanged: (value) {
                              setState(() => _searchQuery = value.trim());
                            },
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search_rounded),
                              hintText: 'Buscar por título o contenido',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (filtered.isEmpty)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.sticky_note_2_outlined,
                              size: 48,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'Todavía no hay notas compartidas.'
                                  : 'No encontramos notas para "$_searchQuery".',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ...filtered.map(
                      (doc) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _NoteCard(
                          doc: doc,
                          onEdit: () => _openNoteEditor(context, noteDoc: doc),
                          onDelete: () => _deleteNote(context, doc.reference),
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _openNoteEditor(
    BuildContext context, {
    QueryDocumentSnapshot<Map<String, dynamic>>? noteDoc,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return;
    }

    final user = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    final familyId = user.data()?['activeFamilyId'] as String?;
    if (familyId == null || familyId.isEmpty || !context.mounted) {
      return;
    }

    final currentTitle = noteDoc?.data()['title'] as String? ?? '';
    final currentContent = noteDoc?.data()['content'] as String? ?? '';
    final titleController = TextEditingController(text: currentTitle);
    final contentController = TextEditingController(text: currentContent);
    try {
      final shouldSave = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) {
          final inset = MediaQuery.of(ctx).viewInsets.bottom;
          return Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + inset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  noteDoc == null ? 'Nueva nota' : 'Editar nota',
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Título'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contentController,
                  minLines: 5,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Contenido',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: const Text('Cancelar'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Guardar'),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );

      final title = titleController.text.trim();
      final content = contentController.text.trim();
      if (shouldSave != true ||
          title.isEmpty ||
          content.isEmpty ||
          !context.mounted) {
        return;
      }

      final payload = {
        'title': title,
        'content': content,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (noteDoc == null) {
        await FirebaseFirestore.instance
            .collection('families')
            .doc(familyId)
            .collection('sharedNotes')
            .add({...payload, 'createdAt': FieldValue.serverTimestamp()});
      } else {
        await noteDoc.reference.update(payload);
      }
    } finally {
      titleController.dispose();
      contentController.dispose();
    }
  }

  Future<void> _deleteNote(
    BuildContext context,
    DocumentReference<Map<String, dynamic>> noteRef,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar nota'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await noteRef.delete();
    }
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({
    required this.doc,
    required this.onEdit,
    required this.onDelete,
  });

  final QueryDocumentSnapshot<Map<String, dynamic>> doc;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final data = doc.data();
    final title = data['title'] as String? ?? '(sin título)';
    final content = data['content'] as String? ?? '';
    final updatedAt = data['updatedAt'] as Timestamp?;
    final updatedText = updatedAt == null
        ? 'Recién creado'
        : 'Actualizado ${MaterialLocalizations.of(context).formatShortDate(updatedAt.toDate())}';

    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit();
                    } else if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'edit', child: Text('Editar')),
                    PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                  ],
                ),
              ],
            ),
            Text(
              content,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              updatedText,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
