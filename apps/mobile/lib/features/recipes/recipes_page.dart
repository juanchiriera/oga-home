import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:oga/core/ads/admob_config.dart';
import 'package:oga/core/ads/inline_native_ad_card.dart';
import 'package:oga/design_system/design_system.dart';
import 'package:oga/features/recipes/recipe_draft.dart';
import 'package:oga/services/functions_region.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RecipesPage extends StatefulWidget {
  const RecipesPage({super.key});

  @override
  State<RecipesPage> createState() => _RecipesPageState();
}

class _RecipesPageState extends State<RecipesPage> {
  bool _isNavigatingToPreview = false;

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
            body: SanctuaryScrollUnderAppBarFade(
              child: Center(
                child: Padding(
                  padding: kSanctuaryScreenPadding,
                  child: Text(
                    'Creá o elegí un hogar para ver recetas.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
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
                body: const SanctuaryScrollUnderAppBarFade(
                  child: Center(child: CircularProgressIndicator()),
                ),
              );
            }
            final docs = snap.data!.docs;
            final scheme = Theme.of(context).colorScheme;

            return Scaffold(
              extendBodyBehindAppBar: true,
              appBar: sanctuaryAppBar(context),
              body: SanctuaryScrollUnderAppBarFade(
                child: ListView(
                  key: const PageStorageKey<String>('recipes-list'),
                  padding: EdgeInsets.fromLTRB(
                    24,
                    MediaQuery.paddingOf(context).top +
                        kSanctuaryAppBarToolbarHeight +
                        8,
                    24,
                    sanctuaryScrollBottomPadding(context),
                  ),
                  children: [
                    Text(
                      'Recetario',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
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
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ImportRecipeFromUrlButton(
                        onPressed: () =>
                            _importRecipeFromUrlFlow(context, familyId),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const InlineNativeAdCard(
                      placement: InlineAdPlacement.recipesBelowImportUrl,
                      height: 92,
                    ),
                    _RecipesStatusBanner(snapshot: snap.data!),
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
                          onOpenPreview: () =>
                              _openPreview(context, familyId, doc.id),
                          onDelete: () =>
                              _deleteRecipe(context, familyId, doc.id, draft),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              floatingActionButton: Padding(
                padding: EdgeInsets.only(
                  bottom: sanctuaryFabBottomInset(context),
                ),
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
            );
          },
        );
      },
    );
  }

  void _openPreview(BuildContext context, String familyId, String recipeId) {
    if (_isNavigatingToPreview || !mounted) {
      return;
    }
    _isNavigatingToPreview = true;
    context
        .push(
          Uri(
            path: '/app/recipes/$recipeId',
            queryParameters: {'familyId': familyId},
          ).toString(),
        )
        .whenComplete(() {
          if (mounted) {
            _isNavigatingToPreview = false;
          }
        });
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
    var editorTab = 0;

    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final screenSize = MediaQuery.sizeOf(ctx);
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 16,
            ),
            title: Text(recipeId == null ? 'Nueva receta' : 'Editar receta'),
            content: SizedBox(
              width: screenSize.width * 0.95,
              height: screenSize.height * 0.8,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 0, label: Text('Editar')),
                        ButtonSegment(value: 1, label: Text('Vista previa')),
                      ],
                      selected: {editorTab},
                      onSelectionChanged: (next) {
                        setLocal(() => editorTab = next.first);
                      },
                    ),
                    const SizedBox(height: 12),
                    if (editorTab == 0)
                      Form(
                        key: formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextFormField(
                              controller: tituloCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Titulo',
                              ),
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
                                labelText:
                                    'Tags (opcional, separados por coma)',
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
                      )
                    else
                      _RecipeEditorPreview(
                        titulo: tituloCtrl.text,
                        descripcion: descripcionCtrl.text,
                        ingredientesRaw: ingredientesCtrl.text,
                        pasosRaw: pasosCtrl.text,
                        tiempoRaw: tiempoCtrl.text,
                        porcionesRaw: porcionesCtrl.text,
                        tagsRaw: tagsCtrl.text,
                        favorita: favorita,
                      ),
                  ],
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

  static Future<void> _importRecipeFromUrlFlow(
    BuildContext context,
    String familyId,
  ) async {
    final urlCtrl = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Importar receta desde URL'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: urlCtrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'URL https://',
                hintText: 'https://sitio.com/receta',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Se traerá contenido público del sitio para armar un borrador editable.',
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, urlCtrl.text.trim()),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
    if (url == null || url.isEmpty || !context.mounted) {
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Importando receta...')),
    );
    try {
      final callable = craftrFunctions().httpsCallable('importRecipeFromUrl');
      final result = await callable.call<Map<String, dynamic>>({
        'familyId': familyId,
        'url': url,
      });
      final payload = Map<String, dynamic>.from(result.data);
      final draft = _ImportedRecipeDraft.fromCallable(payload).toRecipeDraft();
      final legalDisclaimer = payload['legalDisclaimer'] as String?;
      if (!context.mounted) {
        return;
      }
      if (legalDisclaimer != null && legalDisclaimer.trim().isNotEmpty) {
        messenger.showSnackBar(SnackBar(content: Text(legalDisclaimer)));
      }
      await _openEditor(
        context,
        familyId: familyId,
        recipeId: null,
        initial: draft,
      );
    } on FirebaseFunctionsException catch (e) {
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(
        SnackBar(content: Text(e.message ?? 'No se pudo importar la receta')),
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      messenger.showSnackBar(
        const SnackBar(content: Text('Error inesperado al importar receta')),
      );
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

class RecipePreviewPage extends StatelessWidget {
  const RecipePreviewPage({super.key, required this.recipeId, this.familyId});

  final String recipeId;
  final String? familyId;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Sin sesión')));
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
        final activeFamilyId =
            userSnap.data!.data()?['activeFamilyId'] as String?;
        final resolvedFamilyId = familyId ?? activeFamilyId;
        if (resolvedFamilyId == null || resolvedFamilyId.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Vista previa de receta')),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No pudimos determinar el hogar para abrir esta receta.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('families')
              .doc(resolvedFamilyId)
              .collection('recipes')
              .doc(recipeId)
              .snapshots(includeMetadataChanges: true),
          builder: (context, recipeSnap) {
            if (!recipeSnap.hasData) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            final data = recipeSnap.data!.data();
            if (data == null) {
              return Scaffold(
                appBar: AppBar(title: const Text('Vista previa de receta')),
                body: const Center(
                  child: Text('La receta no existe o fue eliminada.'),
                ),
              );
            }
            final draft = RecipeDraft.fromFirestore(data);
            return _RecipePreviewScaffold(draft: draft);
          },
        );
      },
    );
  }
}

class _RecipePreviewScaffold extends StatelessWidget {
  const _RecipePreviewScaffold({required this.draft});

  final RecipeDraft draft;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(draft.titulo)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        children: [
          _RecipeEditorPreview(
            titulo: draft.titulo,
            descripcion: draft.descripcion,
            ingredientesRaw: draft.ingredientes.join('\n'),
            pasosRaw: draft.pasos.join('\n'),
            tiempoRaw: draft.tiempoMin.toString(),
            porcionesRaw: draft.porciones.toString(),
            tagsRaw: draft.tags.join(', '),
            favorita: draft.favorita,
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _ImportedRecipeDraft {
  const _ImportedRecipeDraft({
    required this.titulo,
    required this.descripcion,
    required this.ingredientes,
    required this.pasos,
    required this.tiempoMin,
    required this.porciones,
    required this.tags,
  });

  final String titulo;
  final String descripcion;
  final List<String> ingredientes;
  final List<String> pasos;
  final int tiempoMin;
  final int porciones;
  final List<String> tags;

  static _ImportedRecipeDraft fromCallable(Map<String, dynamic> payload) {
    final draft =
        (payload['draft'] as Map?)?.cast<String, dynamic>() ??
        <String, dynamic>{};
    return _ImportedRecipeDraft(
      titulo: (draft['titulo'] as String? ?? '').trim(),
      descripcion: (draft['descripcion'] as String? ?? '').trim(),
      ingredientes: _toStringList(draft['ingredientes']),
      pasos: _toStringList(draft['pasos']),
      tiempoMin: _toPositiveInt(draft['tiempoMin'], fallback: 15),
      porciones: _toPositiveInt(draft['porciones'], fallback: 2),
      tags: _toStringList(draft['tags']),
    );
  }

  RecipeDraft toRecipeDraft() {
    return RecipeDraft(
      titulo: titulo,
      descripcion: descripcion,
      ingredientes: ingredientes,
      pasos: pasos,
      tiempoMin: tiempoMin,
      porciones: porciones,
      favorita: false,
      tags: tags,
    );
  }

  static List<String> _toStringList(Object? value) {
    if (value is! List) {
      return const [];
    }
    return value
        .whereType<String>()
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
  }

  static int _toPositiveInt(Object? value, {required int fallback}) {
    if (value is int && value > 0) {
      return value;
    }
    if (value is num && value > 0) {
      return value.round();
    }
    return fallback;
  }
}

/// Vista previa de solo lectura alineada con [RecipeDraft] (misma lógica de parseo).
class _RecipeEditorPreview extends StatelessWidget {
  const _RecipeEditorPreview({
    required this.titulo,
    required this.descripcion,
    required this.ingredientesRaw,
    required this.pasosRaw,
    required this.tiempoRaw,
    required this.porcionesRaw,
    required this.tagsRaw,
    required this.favorita,
  });

  final String titulo;
  final String descripcion;
  final String ingredientesRaw;
  final String pasosRaw;
  final String tiempoRaw;
  final String porcionesRaw;
  final String tagsRaw;
  final bool favorita;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ingredientes = RecipeDraft.parseMultiline(ingredientesRaw);
    final pasos = RecipeDraft.parseMultiline(pasosRaw);
    final tags = RecipeDraft.parseTags(tagsRaw);
    final tiempo = int.tryParse(tiempoRaw.trim()) ?? 0;
    final porciones = int.tryParse(porcionesRaw.trim()) ?? 0;
    final title = titulo.trim().isEmpty ? 'Sin título' : titulo.trim();
    final desc = descripcion.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (favorita)
                Padding(
                  padding: const EdgeInsets.only(left: 8, top: 2),
                  child: Icon(
                    Icons.favorite_rounded,
                    color: scheme.error,
                    size: 22,
                  ),
                ),
            ],
          ),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              desc,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
            ),
          ],
          if (tiempo > 0 || porciones > 0) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (tiempo > 0) _PreviewChip(label: '$tiempo min'),
                if (porciones > 0) _PreviewChip(label: '$porciones porciones'),
              ],
            ),
          ],
          if (ingredientes.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Ingredientes',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            ...ingredientes.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('· ', style: theme.textTheme.bodyMedium),
                    Expanded(
                      child: Text(line, style: theme.textTheme.bodyMedium),
                    ),
                  ],
                ),
              ),
            ),
          ],
          if (pasos.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Proceso',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            ...pasos.asMap().entries.map((e) {
              final i = e.key + 1;
              final line = e.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text(
                        '$i.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(line, style: theme.textTheme.bodyMedium),
                    ),
                  ],
                ),
              );
            }),
          ],
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: tags
                  .map((t) => _PreviewChip(label: '#$t'))
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }
}

class _PreviewChip extends StatelessWidget {
  const _PreviewChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({
    required this.draft,
    required this.onToggleFavorite,
    required this.onOpenPreview,
    required this.onEdit,
    required this.onDelete,
  });

  final RecipeDraft draft;
  final VoidCallback onToggleFavorite;
  final VoidCallback onOpenPreview;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onOpenPreview,
        child: CozyCard(
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
        ),
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

class ImportRecipeFromUrlButton extends StatelessWidget {
  const ImportRecipeFromUrlButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  static const String accessibilityLabel = 'Importar receta desde URL';
  static const String buttonText = 'Importar URL';

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: accessibilityLabel,
      child: Semantics(
        button: true,
        label: accessibilityLabel,
        child: FilledButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.link_rounded),
          label: const Text(buttonText),
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
    if (status == _RecipesSyncStatus.synced) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tone = status.tone(scheme);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        CozyCard(
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
        ),
        const SizedBox(height: 12),
      ],
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
    _RecipesSyncStatus.synced => '',
    _RecipesSyncStatus.pendingUpload => 'Pendiente de sincronizar',
    _RecipesSyncStatus.showingCachedData => 'Mostrando datos offline',
  };

  String get message => switch (this) {
    _RecipesSyncStatus.synced => '',
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
