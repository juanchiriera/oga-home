import 'dart:async';

import 'package:craftr_mobile/design_system/design_system.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Whether [value] is a valid HTTPS URL with authority (family links policy).
bool isFamilyLinksHttpsUrl(String value, {Uri? uri}) {
  final parsed = uri ?? Uri.tryParse(value);
  return parsed != null &&
      parsed.scheme.toLowerCase() == 'https' &&
      parsed.hasAuthority &&
      parsed.host.isNotEmpty;
}

/// CRUD de enlaces utiles de la familia activa.
class FamilyLinksPage extends StatelessWidget {
  const FamilyLinksPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Sin sesión')));
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: sanctuaryAppBar(context, title: 'Enlaces útiles'),
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
              child: Text('Creá o elegí un hogar para gestionar enlaces.'),
            );
          }

          final linksRef = FirebaseFirestore.instance
              .collection('families')
              .doc(familyId)
              .collection('family_links');

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: linksRef.orderBy('updatedAt', descending: true).snapshots(),
            builder: (context, linksSnap) {
              if (!linksSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = linksSnap.data!.docs;
              if (docs.isEmpty) {
                return ListView(
                  padding: EdgeInsets.fromLTRB(
                    24,
                    MediaQuery.paddingOf(context).top + kSanctuaryAppBarToolbarHeight + 8,
                    24,
                    28 + MediaQuery.paddingOf(context).bottom,
                  ),
                  children: [
                    CozyCard(
                      child: Row(
                        children: [
                          Icon(Icons.bookmark_outline, color: scheme.secondary),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Guarda enlaces utiles del hogar. La URL debe empezar con https:// y la nota es opcional.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    CozyCard(
                      color: scheme.surfaceContainerLowest,
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        children: [
                          Icon(
                            Icons.link_off_rounded,
                            size: 34,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Todavia no hay enlaces.',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Toca "Agregar" para crear el primero.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }

              return ListView(
                padding: EdgeInsets.fromLTRB(
                  24,
                  MediaQuery.paddingOf(context).top + kSanctuaryAppBarToolbarHeight + 8,
                  24,
                  28 + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  CozyCard(
                    child: Row(
                      children: [
                        Icon(Icons.link_rounded, color: scheme.secondary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Coleccion familiar de enlaces seguros (HTTPS) con nota opcional.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...docs.map((doc) {
                    final data = doc.data();
                    final title = (data['title'] as String?)?.trim() ?? '';
                    final url = (data['url'] as String?)?.trim() ?? '';
                    final note = (data['note'] as String?)?.trim() ?? '';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: CozyCard(
                        color: scheme.surfaceContainerLowest,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: scheme.secondaryContainer,
                              child: Icon(
                                Icons.link_rounded,
                                color: scheme.secondary,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => unawaited(
                                  _tryOpenFamilyLink(context, url),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title.isEmpty
                                          ? _displayHost(url)
                                          : title,
                                      style: theme.textTheme.titleSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      url,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: scheme.primary,
                                          ),
                                    ),
                                    if (note.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        note,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (action) async {
                                if (action == 'edit') {
                                  await _upsertLink(
                                    context: context,
                                    familyId: familyId,
                                    linkId: doc.id,
                                    initialTitle: title,
                                    initialUrl: url,
                                    initialNote: note,
                                  );
                                } else if (action == 'delete') {
                                  await linksRef.doc(doc.id).delete();
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Editar'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Eliminar'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _upsertLink(context: context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Agregar'),
      ),
    );
  }

  static Future<void> _upsertLink({
    required BuildContext context,
    String? familyId,
    String? linkId,
    String initialTitle = '',
    String initialUrl = '',
    String initialNote = '',
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return;
    }

    var resolvedFamilyId = familyId;
    if (resolvedFamilyId == null || resolvedFamilyId.isEmpty) {
      final user = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      resolvedFamilyId = user.data()?['activeFamilyId'] as String?;
    }
    if (resolvedFamilyId == null ||
        resolvedFamilyId.isEmpty ||
        !context.mounted) {
      return;
    }

    final formKey = GlobalKey<FormState>();
    final titleController = TextEditingController(text: initialTitle);
    final urlController = TextEditingController(text: initialUrl);
    final noteController = TextEditingController(text: initialNote);

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(linkId == null ? 'Nuevo enlace' : 'Editar enlace'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Titulo corto (opcional)',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: urlController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'URL (https://...)',
                ),
                validator: (v) {
                  final value = (v ?? '').trim();
                  if (value.isEmpty) {
                    return 'Ingresa una URL';
                  }
                  final uri = Uri.tryParse(value);
                  if (!isFamilyLinksHttpsUrl(value, uri: uri)) {
                    return 'La URL debe ser HTTPS valida';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: noteController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Nota (opcional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() != true) {
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (ok != true || !context.mounted) {
      titleController.dispose();
      urlController.dispose();
      noteController.dispose();
      return;
    }

    final trimmedUrl = urlController.text.trim();
    final trimmedTitle = titleController.text.trim();
    final trimmedNote = noteController.text.trim();
    if (!isFamilyLinksHttpsUrl(trimmedUrl)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Usa un enlace seguro que empiece con https://'),
        ),
      );
      titleController.dispose();
      urlController.dispose();
      noteController.dispose();
      return;
    }

    final payload = <String, dynamic>{
      'url': trimmedUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (trimmedTitle.isNotEmpty) {
      payload['title'] = trimmedTitle;
    }
    if (trimmedNote.isNotEmpty) {
      payload['note'] = trimmedNote;
    }

    final familyLinksRef = FirebaseFirestore.instance
        .collection('families')
        .doc(resolvedFamilyId)
        .collection('family_links');

    if (linkId == null) {
      await familyLinksRef.add(payload);
    } else {
      await familyLinksRef.doc(linkId).update(payload);
    }

    titleController.dispose();
    urlController.dispose();
    noteController.dispose();
  }

  static Future<void> _tryOpenFamilyLink(
    BuildContext context,
    String url,
  ) async {
    final trimmed = url.trim();
    final uri = Uri.tryParse(trimmed);
    if (!isFamilyLinksHttpsUrl(trimmed, uri: uri)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Usa un enlace seguro que empiece con https://'),
        ),
      );
      return;
    }
    final launched = await launchUrl(
      uri!,
      mode: LaunchMode.externalApplication,
    );
    if (launched || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('No se pudo abrir el enlace.')),
    );
  }

  static String _displayHost(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.host.isEmpty) {
      return 'Enlace util';
    }
    return uri.host;
  }
}
