import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:craftr_mobile/design_system/design_system.dart';
import 'package:craftr_mobile/features/recipes/recipe_draft.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RecipesPage extends StatelessWidget {
  const RecipesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Sin sesión'));
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(includeMetadataChanges: true),
      builder: (context, userSnap) {
        if (!userSnap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final familyId = userSnap.data!.data()?['activeFamilyId'] as String?;
        if (familyId == null || familyId.isEmpty) {
          return Scaffold(
            extendBodyBehindAppBar: true,
            appBar: sanctuaryAppBar(context),
            body: Center(
              child: Padding(
                padding: kSanctuaryScreenPadding,
                child: Text(
                  'Creá o elegí un hogar para ver recetas.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
          );
        }
        final query = FirebaseFirestore.instance
            .collection('families')
            .doc(familyId)
            .collection('recipes')
            .orderBy('favorita', descending: true)
            .orderBy('updatedAt', descending: true);

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: query.snapshots(includeMetadataChanges: true),
          builder: (context, snap) {
            if (!snap.hasData) {
              return Scaffold(
                extendBodyBehindAppBar: true,
                appBar: sanctuaryAppBar(context),
                body: const Center(child: CircularProgressIndicator()),
              );
            }
            final docs = snap.data!.docs;
            final scheme = Theme.of(context).colorScheme;

            return Scaffold(
              extendBodyBehindAppBar: true,
              appBar: sanctuaryAppBar(context),
              body: Stack(
                children: [
                  ListView(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      MediaQuery.paddingOf(context).top + kToolbarHeight + 8,
                      24,
                      sanctuaryScrollBottomPadding(context),
                    ),
                    children: [
                      Text(
                        'Recetario',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tu colección de inspiraciones culinarias y tradiciones familiares.',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 20),
                      CozyCard(
                        color: scheme.surfaceContainerLow,
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Importar desde la web',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: scheme.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Pronto vas a poder pegar un enlace y extraer ingredientes y pasos automáticamente.',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                                height: 1.45,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _RecipesStatusBanner(snapshot: snap.data!),
                      const SizedBox(height: 12),
                      CozyCard(
                        child: Text(
                          'Guardá recetas con ingredientes, pasos y porciones.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (docs.isEmpty)
                        CozyCard(
                          child: Text(
                            'Todavía no hay recetas. Creá la primera.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ...docs.map((doc) {
                        final data = doc.data();
                        final draft = RecipeDraft.fromFirestore(data);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _RecipeCard(
                            draft: draft,
                            onToggleFavorite: () =>
                                _toggleFavorite(familyId, doc.id, data),
                            onEdit: () => _openEditor(
                              context,
                              familyId: familyId,
                              recipeId: doc.id,
                              initial: draft,
                            ),
                            onDelete: () =>
                                _deleteRecipe(context, familyId, doc.id, draft),
                          ),
                        );
                      }),
                    ],
                  ),
                  Positioned(
                    right: 20,
                    bottom: 72 + MediaQuery.paddingOf(context).bottom,
                    child: FloatingActionButton.extended(
                      onPressed: () => _openEditor(
                        context,
                        familyId: familyId,
                        recipeId: null,
                        initial: RecipeDraft.empty(),
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Nueva receta'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  static Future<void> _openEditor(
    BuildContext context, {
    required String familyId,
    required String? recipeId,
    required RecipeDraft initial,
  }) async {
    final formKey = GlobalKey<FormState>();
    final tituloCtrl = TextEditingController(text: initial.titulo);
    final descripcionCtrl = TextEditingController(text: initial.descripcion);
    final ingredientesCtrl = TextEditingController(
      text: initial.ingredientes.join('\n'),
    );
    final pasosCtrl = TextEditingController(text: initial.pasos.join('\n'));
    final tagsCtrl = TextEditingController(text: initial.tags.join(', '));
    final tiempoCtrl = TextEditingController(
      text: initial.tiempoMin.toString(),
    );
    final porcionesCtrl = TextEditingController(
      text: initial.porciones.toString(),
    );
    var favorita = initial.favorita;

    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: Text(recipeId == null ? 'Nueva receta' : 'Editar receta'),
            content: SizedBox(
              width: 520,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: tituloCtrl,
                        decoration: const InputDecoration(labelText: 'Titulo'),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Obligatorio'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: descripcionCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Descripcion',
                        ),
                        minLines: 2,
                        maxLines: 4,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Obligatorio'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: ingredientesCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Ingredientes (uno por línea)',
                        ),
                        minLines: 3,
                        maxLines: 6,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: pasosCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Pasos (uno por línea)',
                        ),
                        minLines: 3,
                        maxLines: 6,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: tiempoCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Tiempo (min)',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: porcionesCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Porciones',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: tagsCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Tags (opcional, separados por coma)',
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        value: favorita,
                        title: const Text('Marcar como favorita'),
                        onChanged: (v) => setLocal(() => favorita = v),
                      ),
                    ],
                  ),
                ),
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
          );
        },
      ),
    );

    if (save != true || !context.mounted) {
      return;
    }

    final parsedTiempo = int.tryParse(tiempoCtrl.text.trim()) ?? 0;
    final parsedPorciones = int.tryParse(porcionesCtrl.text.trim()) ?? 0;
    final draft = RecipeDraft(
      titulo: tituloCtrl.text,
      descripcion: descripcionCtrl.text,
      ingredientes: RecipeDraft.parseMultiline(ingredientesCtrl.text),
      pasos: RecipeDraft.parseMultiline(pasosCtrl.text),
      tiempoMin: parsedTiempo,
      porciones: parsedPorciones,
      favorita: favorita,
      tags: RecipeDraft.parseTags(tagsCtrl.text),
    );
    final error = draft.validationError();
    if (error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return;
    }

    final recipes = FirebaseFirestore.instance
        .collection('families')
        .doc(familyId)
        .collection('recipes');
    if (recipeId == null) {
      await recipes.add(draft.toFirestore(uid: uid, isCreate: true));
    } else {
      await recipes
          .doc(recipeId)
          .update(draft.toFirestore(uid: uid, isCreate: false));
    }
  }

  static Future<void> _toggleFavorite(
    String familyId,
    String recipeId,
    Map<String, dynamic> currentData,
  ) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return;
    }
    final current = currentData['favorita'] as bool? ?? false;
    await FirebaseFirestore.instance
        .collection('families')
        .doc(familyId)
        .collection('recipes')
        .doc(recipeId)
        .update({
          'favorita': !current,
          'updatedBy': uid,
          'updatedAt': FieldValue.serverTimestamp(),
          'clientUpdatedAt': Timestamp.now(),
          'conflictPolicy': 'lww-v1',
        });
  }

  static Future<void> _deleteRecipe(
    BuildContext context,
    String familyId,
    String recipeId,
    RecipeDraft draft,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar receta'),
        content: Text('¿Querés eliminar "${draft.titulo}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm != true) {
      return;
    }
    await FirebaseFirestore.instance
        .collection('families')
        .doc(familyId)
        .collection('recipes')
        .doc(recipeId)
        .delete();
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({
    required this.draft,
    required this.onToggleFavorite,
    required this.onEdit,
    required this.onDelete,
  });

  final RecipeDraft draft;
  final VoidCallback onToggleFavorite;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return CozyCard(
      color: scheme.surfaceContainerLowest,
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  draft.titulo,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  draft.descripcion,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _MetaChip(label: '${draft.tiempoMin} min'),
                    _MetaChip(label: '${draft.porciones} porciones'),
                    _MetaChip(
                      label: '${draft.ingredientes.length} ingredientes',
                    ),
                    _MetaChip(label: '${draft.pasos.length} pasos'),
                    ...draft.tags.map((tag) => _MetaChip(label: '#$tag')),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                onPressed: onToggleFavorite,
                icon: Icon(
                  draft.favorita
                      ? Icons.favorite_rounded
                      : Icons.favorite_border,
                  color: draft.favorita
                      ? scheme.error
                      : scheme.onSurfaceVariant,
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
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _RecipesStatusBanner extends StatelessWidget {
  const _RecipesStatusBanner({required this.snapshot});

  final QuerySnapshot<Map<String, dynamic>> snapshot;

  @override
  Widget build(BuildContext context) {
    final status = _RecipesSyncStatus.fromSnapshot(snapshot);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tone = status.tone(scheme);
    return CozyCard(
      color: scheme.surfaceContainer,
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: tone,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  status.message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _RecipesSyncStatus {
  synced,
  pendingUpload,
  showingCachedData;

  static _RecipesSyncStatus fromSnapshot(
    QuerySnapshot<Map<String, dynamic>> s,
  ) {
    if (s.metadata.hasPendingWrites) {
      return _RecipesSyncStatus.pendingUpload;
    }
    if (s.metadata.isFromCache) {
      return _RecipesSyncStatus.showingCachedData;
    }
    return _RecipesSyncStatus.synced;
  }

  String get label => switch (this) {
    _RecipesSyncStatus.synced => 'Sincronizado',
    _RecipesSyncStatus.pendingUpload => 'Pendiente de sincronizar',
    _RecipesSyncStatus.showingCachedData => 'Mostrando datos offline',
  };

  String get message => switch (this) {
    _RecipesSyncStatus.synced => 'Tus recetas están guardadas en la nube.',
    _RecipesSyncStatus.pendingUpload =>
      'Hay cambios locales que se enviarán al reconectar.',
    _RecipesSyncStatus.showingCachedData =>
      'Estás viendo la última versión local disponible.',
  };

  Color tone(ColorScheme scheme) => switch (this) {
    _RecipesSyncStatus.synced => scheme.secondary,
    _RecipesSyncStatus.pendingUpload => scheme.tertiary,
    _RecipesSyncStatus.showingCachedData => scheme.onSurfaceVariant,
  };
}
