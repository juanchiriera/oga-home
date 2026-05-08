import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:oga/core/ads/admob_config.dart';
import 'package:oga/core/ads/inline_native_ad_card.dart';
import 'package:oga/design_system/design_system.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Estados de stock (producto): hay · queda poco · no hay.
enum StockLevel {
  hay,
  low,
  out;

  String get label => switch (this) {
    StockLevel.hay => 'Hay',
    StockLevel.low => 'Queda poco',
    StockLevel.out => 'No hay',
  };

  static StockLevel parse(String? raw) {
    return StockLevel.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => StockLevel.hay,
    );
  }

  /// Ciclo rápido desde Inicio (tarjeta despensa): hay → queda poco → no hay → hay.
  StockLevel get nextInQuickCycle => switch (this) {
    StockLevel.hay => StockLevel.low,
    StockLevel.low => StockLevel.out,
    StockLevel.out => StockLevel.hay,
  };

  /// Punto de estado en listas: rojo (no hay), amarillo (queda poco), verde (hay).
  Color indicatorDotColor(ColorScheme scheme) => switch (this) {
    StockLevel.out => scheme.error,
    StockLevel.low =>
      scheme.brightness == Brightness.dark
          ? const Color(0xFFFFE082)
          : const Color(0xFFF9A825),
    StockLevel.hay => scheme.secondary,
  };
}

enum StockViewFilter {
  all,
  inStock,
  missing;

  String get label => switch (this) {
    StockViewFilter.all => 'Todos',
    StockViewFilter.inStock => 'En stock',
    StockViewFilter.missing => 'Falta comprar',
  };

  String get compactLabel => switch (this) {
    StockViewFilter.all => 'Todos',
    StockViewFilter.inStock => 'Stock',
    StockViewFilter.missing => 'Falta',
  };
}

class StockListPage extends StatefulWidget {
  const StockListPage({super.key});

  @override
  State<StockListPage> createState() => _StockListPageState();

  static bool _readIncludeLow(Map<String, dynamic>? familyData) {
    final settings = familyData?['settings'];
    if (settings is! Map<String, dynamic>) {
      return false;
    }
    final stock = settings['stock'];
    if (stock is! Map<String, dynamic>) {
      return false;
    }
    return stock['include_low'] == true;
  }

  static bool isInStockLevel(StockLevel level) => level != StockLevel.out;

  static bool isMissingLevel(StockLevel level, {required bool includeLow}) {
    if (level == StockLevel.out) {
      return true;
    }
    return includeLow && level == StockLevel.low;
  }

  static bool matchesFilter(
    StockLevel level, {
    required StockViewFilter filter,
    required bool includeLow,
  }) {
    return switch (filter) {
      StockViewFilter.all => true,
      StockViewFilter.inStock => isInStockLevel(level),
      StockViewFilter.missing => isMissingLevel(level, includeLow: includeLow),
    };
  }

  static Map<StockViewFilter, int> buildFilterCounts(
    Iterable<StockLevel> levels, {
    required bool includeLow,
  }) {
    final counts = <StockViewFilter, int>{
      for (final filter in StockViewFilter.values) filter: 0,
    };
    for (final level in levels) {
      for (final filter in StockViewFilter.values) {
        if (matchesFilter(level, filter: filter, includeLow: includeLow)) {
          counts[filter] = (counts[filter] ?? 0) + 1;
        }
      }
    }
    return counts;
  }

  static Future<void> _showSettings(
    BuildContext context, {
    required DocumentReference<Map<String, dynamic>> familyRef,
    required bool includeLow,
  }) async {
    var localIncludeLow = includeLow;
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: const Text('Ajustes de stock'),
            content: SwitchListTile(
              value: localIncludeLow,
              contentPadding: EdgeInsets.zero,
              title: const Text('Incluir "queda poco"'),
              subtitle: const Text(
                'También mostrar ítems low en Falta comprar',
              ),
              onChanged: (value) => setLocal(() => localIncludeLow = value),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
    if (save != true) {
      return;
    }
    await familyRef.set({
      'settings': {
        'stock': {'include_low': localIncludeLow},
      },
    }, SetOptions(merge: true));
  }

  static Future<void> _addItem(BuildContext context) async {
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
    var name = '';
    var level = StockLevel.hay;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: const Text('Nuevo ítem'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  onChanged: (v) => name = v,
                ),
                const SizedBox(height: 12),
                Text('Estado', style: Theme.of(ctx).textTheme.labelLarge),
                SegmentedButton<StockLevel>(
                  segments: StockLevel.values
                      .map((e) => ButtonSegment(value: e, label: Text(e.label)))
                      .toList(),
                  selected: {level},
                  onSelectionChanged: (s) => setLocal(() => level = s.first),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
    if (ok != true || name.trim().isEmpty || !context.mounted) {
      return;
    }
    await FirebaseFirestore.instance
        .collection('families')
        .doc(familyId)
        .collection('stockItems')
        .add({
          'name': name.trim(),
          'state': level.name,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': uid,
          'clientUpdatedAt': Timestamp.now(),
          'conflictPolicy': 'lww-v1',
        });
  }

  static Future<void> _editItem(
    BuildContext context,
    String familyId,
    String itemId,
    String currentName,
    StockLevel current,
  ) async {
    var name = currentName;
    var level = current;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: const Text('Editar ítem'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  initialValue: currentName,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  onChanged: (v) => name = v,
                ),
                const SizedBox(height: 12),
                Text('Estado', style: Theme.of(ctx).textTheme.labelLarge),
                SegmentedButton<StockLevel>(
                  segments: StockLevel.values
                      .map((e) => ButtonSegment(value: e, label: Text(e.label)))
                      .toList(),
                  selected: {level},
                  onSelectionChanged: (s) => setLocal(() => level = s.first),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Guardar'),
              ),
            ],
          );
        },
      ),
    );
    if (ok != true || name.trim().isEmpty || !context.mounted) {
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return;
    }
    await FirebaseFirestore.instance
        .collection('families')
        .doc(familyId)
        .collection('stockItems')
        .doc(itemId)
        .update({
          'name': name.trim(),
          'state': level.name,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': uid,
          'clientUpdatedAt': Timestamp.now(),
          'conflictPolicy': 'lww-v1',
        });
  }

  static Future<void> cycleItemState({
    required String familyId,
    required String itemId,
    required StockLevel current,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return;
    }
    final next = current.nextInQuickCycle;
    await FirebaseFirestore.instance
        .collection('families')
        .doc(familyId)
        .collection('stockItems')
        .doc(itemId)
        .update({
          'state': next.name,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': uid,
          'clientUpdatedAt': Timestamp.now(),
          'conflictPolicy': 'lww-v1',
        });
  }
}

class _StockListPageState extends State<StockListPage> {
  final _searchController = TextEditingController();
  String _query = '';
  StockViewFilter _selectedFilter = StockViewFilter.all;

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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: sanctuaryAppBar(context),
      body: SanctuaryScrollUnderAppBarFade(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .snapshots(includeMetadataChanges: true),
          builder: (context, userSnap) {
            if (!userSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final familyId =
                userSnap.data!.data()?['activeFamilyId'] as String?;
            if (familyId == null || familyId.isEmpty) {
              return Center(
                child: Padding(
                  padding: kSanctuaryScreenPadding,
                  child: Text(
                    'Creá o elegí un hogar para ver la despensa.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              );
            }
            final familyRef = FirebaseFirestore.instance
                .collection('families')
                .doc(familyId);
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: familyRef.snapshots(includeMetadataChanges: true),
              builder: (context, familySnap) {
                if (!familySnap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final includeLow = StockListPage._readIncludeLow(
                  familySnap.data?.data(),
                );
                final base = familyRef.collection('stockItems');
                final Query<Map<String, dynamic>> query = base.orderBy('name');
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: query.snapshots(includeMetadataChanges: true),
                  builder: (context, q) {
                    if (!q.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = q.data!.docs;
                    final parsed = docs
                        .map(
                          (d) => (
                            doc: d,
                            name: d.data()['name'] as String? ?? '(sin nombre)',
                            level: StockLevel.parse(
                              d.data()['state'] as String?,
                            ),
                          ),
                        )
                        .toList();
                    final counts = StockListPage.buildFilterCounts(
                      parsed.map((item) => item.level),
                      includeLow: includeLow,
                    );
                    final qLower = _query.toLowerCase();
                    final filterOnly = parsed
                        .where(
                          (item) => StockListPage.matchesFilter(
                            item.level,
                            filter: _selectedFilter,
                            includeLow: includeLow,
                          ),
                        )
                        .toList();
                    final filtered = qLower.isEmpty
                        ? filterOnly
                        : filterOnly
                              .where(
                                (item) =>
                                    item.name.toLowerCase().contains(qLower),
                              )
                              .toList();
                    final hasItems = filtered.isNotEmpty;

                    return ListView(
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
                          'Despensa y stock',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Gestioná lo que falta comprar y el estado de cada ítem.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 20),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(999),
                            boxShadow: [
                              BoxShadow(
                                color: scheme.shadow.withValues(alpha: 0.04),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (v) => setState(() => _query = v.trim()),
                            decoration: InputDecoration(
                              hintText: 'Buscar en la despensa…',
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: scheme.outline,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const InlineNativeAdCard(
                          placement: InlineAdPlacement.stockBelowSearch,
                          height: 112,
                          margin: EdgeInsets.only(bottom: 12),
                        ),
                        _StockSyncBanner(snapshot: q.data!),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _selectedFilter.label,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.tune_rounded),
                              tooltip: 'Ajustes de stock',
                              onPressed: () => StockListPage._showSettings(
                                context,
                                familyRef: familyRef,
                                includeLow: includeLow,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          includeLow
                              ? 'Falta comprar incluye: no hay + queda poco'
                              : 'Falta comprar incluye: solo no hay',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<StockViewFilter>(
                            expandedInsets: EdgeInsets.zero,
                            style: const ButtonStyle(
                              visualDensity: VisualDensity.compact,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            segments: StockViewFilter.values
                                .map(
                                  (filter) => ButtonSegment(
                                    value: filter,
                                    label: Text(
                                      '${filter.compactLabel} ${counts[filter] ?? 0}',
                                    ),
                                  ),
                                )
                                .toList(),
                            selected: {_selectedFilter},
                            onSelectionChanged: (selection) {
                              setState(() => _selectedFilter = selection.first);
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (!hasItems)
                          CozyCard(
                            child: Text(
                              _query.isEmpty
                                  ? switch (_selectedFilter) {
                                      StockViewFilter.all =>
                                        'No hay ítems en stock.',
                                      StockViewFilter.inStock =>
                                        'No hay ítems en stock.',
                                      StockViewFilter.missing =>
                                        'Nada pendiente para comprar.',
                                    }
                                  : 'No hay coincidencias para “$_query”.',
                              style: theme.textTheme.bodyMedium,
                            ),
                          )
                        else
                          ...filtered.map((item) {
                            final d = item.doc;
                            final name = item.name;
                            final level = item.level;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: StockItemTile(
                                name: name,
                                level: level,
                                onTap: () => StockListPage._editItem(
                                  context,
                                  familyId,
                                  d.id,
                                  name,
                                  level,
                                ),
                                onDelete: () => base.doc(d.id).delete(),
                              ),
                            );
                          }),
                        if (_query.isEmpty &&
                            filtered.length != filterOnly.length)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Mostrando ${filtered.length} de ${filterOnly.length} '
                              'en ${_selectedFilter.label.toLowerCase()}.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: Padding(
        padding: EdgeInsets.only(
          bottom: 72 + MediaQuery.paddingOf(context).bottom,
        ),
        child: FloatingActionButton.extended(
          onPressed: () => StockListPage._addItem(context),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Ítem'),
        ),
      ),
    );
  }
}

class _StockSyncBanner extends StatelessWidget {
  const _StockSyncBanner({required this.snapshot});

  final QuerySnapshot<Map<String, dynamic>> snapshot;

  @override
  Widget build(BuildContext context) {
    final status = _StockSyncStatus.fromSnapshot(snapshot);
    if (status == _StockSyncStatus.synced) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tone = status.tone(scheme);
    return CozyCard(
      color: scheme.surfaceContainerLow,
      padding: const EdgeInsets.all(18),
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

class StockItemTile extends StatelessWidget {
  const StockItemTile({
    super.key,
    required this.name,
    required this.level,
    required this.onTap,
    required this.onDelete,
  });

  final String name;
  final StockLevel level;
  final Future<void> Function() onTap;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dot = level.indicatorDotColor(scheme);
    return CozyCard(
      color: scheme.surfaceContainerLowest,
      padding: EdgeInsets.zero,
      child: InkWell(
        key: const Key('stock-item-tile'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  color: scheme.outline,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: dot,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          level.label,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                key: const Key('stock-item-menu'),
                onSelected: (action) async {
                  if (action == 'edit') {
                    await onTap();
                  } else if (action == 'delete') {
                    await onDelete();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Editar')),
                  PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _StockSyncStatus {
  synced,
  pendingUpload,
  showingCachedData;

  static _StockSyncStatus fromSnapshot(QuerySnapshot<Map<String, dynamic>> s) {
    if (s.metadata.hasPendingWrites) {
      return _StockSyncStatus.pendingUpload;
    }
    if (s.metadata.isFromCache) {
      return _StockSyncStatus.showingCachedData;
    }
    return _StockSyncStatus.synced;
  }

  String get label => switch (this) {
    _StockSyncStatus.synced => '',
    _StockSyncStatus.pendingUpload => 'Pendiente de sincronizar',
    _StockSyncStatus.showingCachedData => 'Mostrando datos offline',
  };

  String get message => switch (this) {
    _StockSyncStatus.synced => '',
    _StockSyncStatus.pendingUpload =>
      'Hay cambios locales que se enviarán al reconectar.',
    _StockSyncStatus.showingCachedData =>
      'Estás viendo la última versión local disponible.',
  };

  Color tone(ColorScheme scheme) => switch (this) {
    _StockSyncStatus.synced => scheme.secondary,
    _StockSyncStatus.pendingUpload => scheme.tertiary,
    _StockSyncStatus.showingCachedData => scheme.onSurfaceVariant,
  };
}
