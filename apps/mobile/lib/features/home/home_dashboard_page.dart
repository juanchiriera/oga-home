import 'package:craftr_mobile/core/flavor.dart';
import 'package:craftr_mobile/core/revenuecat_config.dart';
import 'package:craftr_mobile/design_system/design_system.dart';
import 'package:craftr_mobile/features/expenses/expenses_page.dart';
import 'package:craftr_mobile/features/recipes/recipe_draft.dart';
import 'package:craftr_mobile/features/stock/stock_list_page.dart';
import 'package:craftr_mobile/services/auth_service.dart';
import 'package:craftr_mobile/services/purchases_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

class HomeDashboardPage extends StatefulWidget {
  const HomeDashboardPage({super.key, required this.flavor});

  final AppFlavor flavor;

  @override
  State<HomeDashboardPage> createState() => _HomeDashboardPageState();
}

class _HomeDashboardPageState extends State<HomeDashboardPage> {
  final _purchasesService = PurchasesService();
  late Future<_BillingUiState> _billingState;

  @override
  void initState() {
    super.initState();
    _billingState = _loadBillingState();
  }

  Future<_BillingUiState> _loadBillingState() async {
    if (!_purchasesService.isConfigured) {
      return const _BillingUiState.notConfigured();
    }
    try {
      final offerings = await _purchasesService.fetchOfferings();
      if (offerings == null || offerings.current == null) {
        return const _BillingUiState.empty();
      }
      final packageCount = offerings.current!.availablePackages.length;
      return _BillingUiState.available(packageCount: packageCount);
    } catch (_) {
      return const _BillingUiState.error();
    }
  }

  Future<void> _refreshBillingState() async {
    final next = await _loadBillingState();
    if (mounted) {
      setState(() => _billingState = Future.value(next));
    }
  }

  String _greetingPrefix() {
    final h = DateTime.now().hour;
    if (h < 13) return 'Buenos días';
    if (h < 20) return 'Buenas tardes';
    return 'Buenas noches';
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Sin sesión')));
    }
    final user = FirebaseAuth.instance.currentUser!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final firstName = _firstName(user);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: sanctuaryAppBar(
        context,
        leading: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: IconButton(
            tooltip: 'Perfil',
            onPressed: () => context.push('/profile'),
            icon: CircleAvatar(
              radius: 18,
              backgroundColor: scheme.secondaryContainer,
              backgroundImage: user.photoURL != null && user.photoURL!.isNotEmpty
                  ? NetworkImage(user.photoURL!)
                  : null,
              child: user.photoURL == null || user.photoURL!.isEmpty
                  ? Text(
                      firstName.isNotEmpty ? firstName[0].toUpperCase() : '?',
                      style: TextStyle(
                        color: scheme.onSecondaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await AuthService().signOut();
              if (context.mounted) {
                context.go('/sign-in');
              }
            },
            child: Text(
              'Salir',
              style: TextStyle(
                color: scheme.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, userSnap) {
          if (!userSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = userSnap.data!.data();
          final familyId = data?['activeFamilyId'] as String?;
          return ListView(
            padding: EdgeInsets.fromLTRB(
              24,
              MediaQuery.paddingOf(context).top + kToolbarHeight + 8,
              24,
              sanctuaryScrollBottomPadding(context),
            ),
            children: [
              SanctuaryAssistantHero(
                greetingLine: '${_greetingPrefix()}, $firstName',
                subtitle: familyId != null && familyId.isNotEmpty
                    ? 'Acá tenés un vistazo del hogar: despensa, gastos, notas y recetas en un solo lugar.'
                    : 'Creá tu hogar para empezar a coordinar despensa, gastos y notas con quienes viven con vos.',
              ),
              const SizedBox(height: 12),
              Text(
                widget.flavor.displayName,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: scheme.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              FutureBuilder<_BillingUiState>(
                future: _billingState,
                builder: (context, snap) {
                  final state = snap.data;
                  if (snap.connectionState == ConnectionState.waiting && state == null) {
                    return CozyCard(
                      color: scheme.surfaceContainer,
                      child: const Row(
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Expanded(child: Text('Cargando planes sandbox...')),
                        ],
                      ),
                    );
                  }
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _BillingStateCard(
                        state: state ?? const _BillingUiState.error(),
                        onRetry: _refreshBillingState,
                      ),
                      if (RevenueCatConfig.isConfigured) ...[
                        const SizedBox(height: 10),
                        _RevenueCatUiActions(),
                      ],
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),
              if (familyId == null || familyId.isEmpty) ...[
                CozyCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Tu espacio familiar',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: scheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Creá un hogar para compartir despensa, gastos y notas.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => context.push('/create-family'),
                        child: const Text('Crear hogar'),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton(
                        onPressed: null,
                        child: const Text('Invitaciones'),
                      ),
                    ],
                  ),
                ),
              ] else
                _HomeFamilyOverview(
                  familyId: familyId,
                  onOpenStock: () => context.go('/app?tab=stock'),
                  onOpenExpenses: () => context.go('/app?tab=gastos'),
                  onOpenNotes: () => context.go('/app?tab=notas'),
                  onOpenRecipes: () => context.go('/app?tab=recetas'),
                  onInvites: () => context.push('/invites'),
                ),
            ],
          );
        },
      ),
    );
  }

  static String _firstName(User user) {
    final raw = user.displayName?.trim();
    if (raw != null && raw.isNotEmpty) {
      return raw.split(RegExp(r'\s+')).first;
    }
    final email = user.email;
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }
    return 'familia';
  }
}

class _HomeFamilyOverview extends StatelessWidget {
  const _HomeFamilyOverview({
    required this.familyId,
    required this.onOpenStock,
    required this.onOpenExpenses,
    required this.onOpenNotes,
    required this.onOpenRecipes,
    required this.onInvites,
  });

  final String familyId;
  final VoidCallback onOpenStock;
  final VoidCallback onOpenExpenses;
  final VoidCallback onOpenNotes;
  final VoidCallback onOpenRecipes;
  final VoidCallback onInvites;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final familyRef = FirebaseFirestore.instance.collection('families').doc(familyId);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: familyRef
          .collection('expenses')
          .orderBy('occurredAt', descending: true)
          .limit(80)
          .snapshots(),
      builder: (context, expSnap) {
        final monthStart = DateTime(DateTime.now().year, DateTime.now().month, 1);
        var monthlyTotal = 0.0;
        final byCategory = <String, double>{};
        if (expSnap.hasData) {
          for (final doc in expSnap.data!.docs) {
            final d = doc.data();
            final amount = (d['amount'] as num?)?.toDouble() ?? 0;
            final key = d['categoryKey'] as String? ?? 'other';
            final occurredAt = (d['occurredAt'] as Timestamp?)?.toDate();
            byCategory[key] = (byCategory[key] ?? 0) + amount;
            if (occurredAt != null && !occurredAt.isBefore(monthStart)) {
              monthlyTotal += amount;
            }
          }
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: familyRef
              .collection('stockItems')
              .where('state', whereIn: ['out', 'low'])
              .orderBy('name')
              .limit(8)
              .snapshots(includeMetadataChanges: true),
          builder: (context, stockSnap) {
            final stockDocs = stockSnap.data?.docs ?? const [];
            final alertCount = stockDocs.length;

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: familyRef
                  .collection('sharedNotes')
                  .orderBy('updatedAt', descending: true)
                  .limit(1)
                  .snapshots(),
              builder: (context, notesSnap) {
                final noteDoc = notesSnap.data?.docs.isNotEmpty == true
                    ? notesSnap.data!.docs.first
                    : null;

                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: familyRef
                      .collection('recipes')
                      .orderBy('favorita', descending: true)
                      .orderBy('updatedAt', descending: true)
                      .limit(1)
                      .snapshots(includeMetadataChanges: true),
                  builder: (context, recSnap) {
                    final recDoc = recSnap.data?.docs.isNotEmpty == true
                        ? recSnap.data!.docs.first
                        : null;
                    RecipeDraft? featured;
                    if (recDoc != null) {
                      featured = RecipeDraft.fromFirestore(recDoc.data());
                    }

                    final topChips = kExpenseCategories
                        .where((c) => (byCategory[c.key] ?? 0) > 0)
                        .take(4)
                        .toList();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Hogar activo',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: scheme.secondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          familyId,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton(
                                onPressed: onInvites,
                                child: const Text('Invitaciones'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        InkWell(
                          borderRadius: BorderRadius.circular(28),
                          onTap: onOpenExpenses,
                          child: CozyCard(
                            color: scheme.surfaceContainerLow,
                            padding: const EdgeInsets.all(22),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Gasto del mes',
                                            style: theme.textTheme.labelLarge?.copyWith(
                                              color: scheme.secondary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            '\$${monthlyTotal.toStringAsFixed(2)}',
                                            style: theme.textTheme.headlineSmall?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: scheme.primary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    FilledButton.tonalIcon(
                                      onPressed: onOpenExpenses,
                                      icon: const Icon(Icons.receipt_long_rounded, size: 20),
                                      label: const Text('Escanear'),
                                    ),
                                  ],
                                ),
                                if (topChips.isNotEmpty) ...[
                                  const SizedBox(height: 18),
                                  Text(
                                    'Categorías con movimiento',
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: topChips
                                        .map(
                                          (c) => Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 14,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: scheme.surfaceContainerHigh,
                                              borderRadius: BorderRadius.circular(999),
                                            ),
                                            child: Text(
                                              '${c.label}: \$${(byCategory[c.key] ?? 0).toStringAsFixed(0)}',
                                              style: theme.textTheme.labelSmall?.copyWith(
                                                color: scheme.secondary,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        InkWell(
                          borderRadius: BorderRadius.circular(28),
                          onTap: onOpenStock,
                          child: CozyCard(
                            color: scheme.surfaceContainer,
                            padding: const EdgeInsets.all(22),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Alertas de despensa',
                                        style: theme.textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: scheme.primary,
                                        ),
                                      ),
                                    ),
                                    Icon(Icons.kitchen_outlined, color: scheme.secondary),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  alertCount == 0
                                      ? 'No hay ítems marcados como “no hay” o “queda poco”.'
                                      : '$alertCount ítem${alertCount == 1 ? '' : 's'} para revisar.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 14),
                                if (!stockSnap.hasData)
                                  const LinearProgressIndicator(minHeight: 3)
                                else if (stockDocs.isEmpty)
                                  Text(
                                    'Todo en orden por ahora.',
                                    style: theme.textTheme.bodyMedium,
                                  )
                                else
                                  ...stockDocs.take(3).map((d) {
                                    final s = d.data();
                                    final name = s['name'] as String? ?? '(sin nombre)';
                                    final level = StockLevel.parse(s['state'] as String?);
                                    final isOut = level == StockLevel.out;
                                    final dotColor = isOut ? scheme.error : scheme.tertiary;
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 10),
                                      child: CozyCard(
                                        color: scheme.surfaceContainerLowest,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 12,
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: dotColor,
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: dotColor.withValues(alpha: 0.45),
                                                    blurRadius: 8,
                                                  ),
                                                ],
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
                                                  Text(
                                                    level.label,
                                                    style: theme.textTheme.labelSmall?.copyWith(
                                                      color: scheme.onSurfaceVariant,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Icon(Icons.add_circle_outline, color: scheme.primary),
                                          ],
                                        ),
                                      ),
                                    );
                                  }),
                                const SizedBox(height: 8),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton(
                                    onPressed: onOpenStock,
                                    child: const Text('Ver despensa completa'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        InkWell(
                          borderRadius: BorderRadius.circular(28),
                          onTap: onOpenNotes,
                          child: CozyCard(
                            color: scheme.surfaceContainerHigh,
                            padding: const EdgeInsets.all(22),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.description_outlined, color: scheme.primary),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Nota reciente',
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: scheme.primary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                if (noteDoc == null)
                                  Text(
                                    'Todavía no hay notas compartidas.',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  )
                                else ...[
                                  CozyCard(
                                    color: scheme.surfaceContainerLow,
                                    padding: const EdgeInsets.all(18),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          noteDoc.data()['title'] as String? ?? '(sin título)',
                                          style: theme.textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: scheme.primary,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          noteDoc.data()['content'] as String? ?? '',
                                          maxLines: 4,
                                          overflow: TextOverflow.ellipsis,
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                            height: 1.45,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (featured != null) ...[
                          const SizedBox(height: 16),
                          InkWell(
                            borderRadius: BorderRadius.circular(28),
                            onTap: onOpenRecipes,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(28),
                              child: Stack(
                                children: [
                                  Positioned.fill(
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            scheme.surfaceContainerHighest,
                                            scheme.surfaceContainer,
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(22),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: scheme.tertiaryContainer,
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            'Receta destacada',
                                            style: theme.textTheme.labelSmall?.copyWith(
                                              color: scheme.onTertiaryContainer,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Text(
                                          featured.titulo,
                                          style: theme.textTheme.headlineSmall?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: scheme.onSurface,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.schedule_rounded,
                                              size: 18,
                                              color: scheme.secondary,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '${featured.tiempoMin} min',
                                              style: theme.textTheme.labelMedium?.copyWith(
                                                color: scheme.secondary,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Icon(
                                              Icons.restaurant_menu_rounded,
                                              size: 18,
                                              color: scheme.secondary,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '${featured.porciones} porciones',
                                              style: theme.textTheme.labelMedium?.copyWith(
                                                color: scheme.secondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

/// Paywall y Customer Center de [purchases_ui_flutter] (requiere paywalls en el dashboard RC).
class _RevenueCatUiActions extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CozyCard(
      color: scheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'RevenueCat UI',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Paywall y centro de cliente configurados en RevenueCat.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: () => _presentPaywall(context),
                child: const Text('Paywall'),
              ),
              OutlinedButton(
                onPressed: () => _presentCustomerCenter(context),
                child: const Text('Centro de cliente'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static Future<void> _presentPaywall(BuildContext context) async {
    try {
      await RevenueCatUI.presentPaywall();
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Paywall: $e')),
      );
    }
  }

  static Future<void> _presentCustomerCenter(BuildContext context) async {
    try {
      await RevenueCatUI.presentCustomerCenter();
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Centro de cliente: $e')),
      );
    }
  }
}

class _BillingStateCard extends StatelessWidget {
  const _BillingStateCard({required this.state, required this.onRetry});

  final _BillingUiState state;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return CozyCard(
      color: switch (state.type) {
        _BillingUiStateType.available => scheme.primaryContainer,
        _BillingUiStateType.error => scheme.errorContainer,
        _BillingUiStateType.notConfigured => scheme.surfaceContainer,
        _BillingUiStateType.empty => scheme.surfaceContainerHigh,
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            state.title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(state.message, style: theme.textTheme.bodyMedium?.copyWith(height: 1.45)),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonal(
              onPressed: onRetry,
              child: Text(state.ctaLabel),
            ),
          ),
        ],
      ),
    );
  }
}

enum _BillingUiStateType { available, notConfigured, empty, error }

class _BillingUiState {
  const _BillingUiState._({
    required this.type,
    required this.title,
    required this.message,
    required this.ctaLabel,
  });

  const _BillingUiState.available({required int packageCount})
    : this._(
        type: _BillingUiStateType.available,
        title: 'Planes premium disponibles',
        message:
            'Encontramos $packageCount paquete(s) en sandbox. Ya podés validar compras en entorno de pruebas.',
        ctaLabel: 'Actualizar planes',
      );

  const _BillingUiState.notConfigured()
    : this._(
        type: _BillingUiStateType.notConfigured,
        title: 'Beneficios premium no disponibles en este entorno',
        message:
            'Estamos terminando la configuración de suscripciones. Podés seguir usando todas las funciones base del hogar.',
        ctaLabel: 'Reintentar',
      );

  const _BillingUiState.empty()
    : this._(
        type: _BillingUiStateType.empty,
        title: 'No encontramos planes disponibles por ahora',
        message:
            'No hay ofertas activas en este momento. Tu experiencia actual no cambia y podés intentar nuevamente en unos minutos.',
        ctaLabel: 'Actualizar planes',
      );

  const _BillingUiState.error()
    : this._(
        type: _BillingUiStateType.error,
        title: 'No pudimos cargar los planes',
        message:
            'Revisá tu conexión e intentá de nuevo. Mientras tanto, podés seguir gestionando tu hogar con normalidad.',
        ctaLabel: 'Reintentar',
      );

  final _BillingUiStateType type;
  final String title;
  final String message;
  final String ctaLabel;
}
