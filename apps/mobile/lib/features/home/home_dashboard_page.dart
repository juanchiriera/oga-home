import 'package:oga/core/flavor.dart';
import 'package:oga/core/entitlements_scope.dart';
import 'package:oga/core/monetization.dart';
import 'package:oga/core/revenuecat_config.dart';
import 'package:oga/design_system/design_system.dart';
import 'package:oga/features/expenses/expense_lifecycle.dart';
import 'package:oga/features/expenses/expense_money.dart';
import 'package:oga/features/expenses/expenses_page.dart';
import 'package:oga/l10n/l10n.dart';
import 'package:oga/features/invite/family_invite_flow.dart';
import 'package:oga/features/recipes/recipe_draft.dart';
import 'package:oga/features/stock/stock_list_page.dart';
import 'package:oga/services/auth_service.dart';
import 'package:oga/services/purchases_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

/// Resolves visible title from `families/{id}` document fields (`name`).
String familyDisplayNameFromFirestoreFields(
  Map<String, dynamic>? fields,
  String unnamedLabel,
) {
  final raw = (fields?['name'] as String?)?.trim();
  if (raw == null || raw.isEmpty) return unnamedLabel;
  return raw;
}

class HomeDashboardPage extends StatefulWidget {
  const HomeDashboardPage({super.key, required this.flavor});

  final AppFlavor flavor;

  @override
  State<HomeDashboardPage> createState() => _HomeDashboardPageState();
}

class _HomeDashboardPageState extends State<HomeDashboardPage> {
  final _purchasesService = PurchasesService();
  Future<_BillingUiState>? _billingState;

  @override
  void initState() {
    super.initState();
    if (MonetizationConfig.billingLive) {
      _billingState = _loadBillingState();
    }
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

  Future<void> _openInviteRedeem(BuildContext context) async {
    final token = await showDialog<String?>(
      context: context,
      builder: (ctx) => const _InviteTokenDialog(),
    );
    if (!context.mounted || token == null || token.isEmpty) {
      return;
    }
    var path = token;
    if (path.contains('/invite/')) {
      final i = path.indexOf('/invite/');
      path = path.substring(i + '/invite/'.length);
    }
    path = path.split('?').first.trim();
    if (path.isEmpty) {
      return;
    }
    context.push('/invite/$path');
  }

  String _greetingPrefix(BuildContext context) {
    final l10n = context.l10n;
    final h = DateTime.now().hour;
    if (h < 13) return l10n.homeGreetingMorning;
    if (h < 20) return l10n.homeGreetingAfternoon;
    return l10n.homeGreetingEvening;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(body: Center(child: Text(l10n.homeNoSession)));
    }
    final user = FirebaseAuth.instance.currentUser!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final firstName = _firstName(user, l10n.homeFamilyFallbackName);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: sanctuaryAppBar(
        context,
        leading: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: IconButton(
            tooltip: l10n.homeProfileTooltip,
            onPressed: () => context.push('/profile'),
            icon: CircleAvatar(
              radius: 18,
              backgroundColor: scheme.secondaryContainer,
              backgroundImage:
                  user.photoURL != null && user.photoURL!.isNotEmpty
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
              l10n.homeSignOut,
              style: TextStyle(
                color: scheme.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SanctuaryScrollUnderAppBarFade(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .snapshots(),
          builder: (context, userSnap) {
            if (!userSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = userSnap.data!.data();
            final familyId = data?['activeFamilyId'] as String?;
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
                SanctuaryAssistantHero(
                  greetingLine: l10n.homeGreetingLine(
                    _greetingPrefix(context),
                    firstName,
                  ),
                  subtitle: familyId != null && familyId.isNotEmpty
                      ? l10n.homeHeroSubtitleWithFamily
                      : l10n.homeHeroSubtitleWithoutFamily,
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
                if (MonetizationConfig.billingLive && _billingState != null)
                  FutureBuilder<_BillingUiState>(
                    future: _billingState,
                    builder: (context, snap) {
                      final state = snap.data;
                      if (snap.connectionState == ConnectionState.waiting &&
                          state == null) {
                        return CozyCard(
                          color: scheme.surfaceContainer,
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(l10n.homeLoadingSandboxPlans),
                              ),
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
                            _RevenueCatUiActions(
                              onRevenueCatStateMayHaveChanged: () async {
                                if (!mounted) {
                                  return;
                                }
                                await _refreshBillingState();
                                if (!mounted) {
                                  return;
                                }
                                await MainShellEntitlementsScope.refresh(
                                  this.context,
                                );
                              },
                            ),
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
                          l10n.homeFamilySpaceTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.homeFamilySpaceDescription,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => context.push('/create-family'),
                          child: Text(l10n.homeCreateFamily),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: () => _openInviteRedeem(context),
                          child: Text(l10n.homeInvitations),
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
      ),
    );
  }

  static String _firstName(User user, String fallbackName) {
    final raw = user.displayName?.trim();
    if (raw != null && raw.isNotEmpty) {
      return raw.split(RegExp(r'\s+')).first;
    }
    final email = user.email;
    if (email != null && email.contains('@')) {
      return email.split('@').first;
    }
    return fallbackName;
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
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final familyRef = FirebaseFirestore.instance
        .collection('families')
        .doc(familyId);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: familyRef.snapshots(),
      builder: (context, familySnap) {
        final familyDoc = familySnap.data;
        final householdLabel = !familySnap.hasData || familyDoc == null
            ? '\u2026'
            : (!familyDoc.exists
                  ? l10n.homeUnnamedItem
                  : familyDisplayNameFromFirestoreFields(
                      familyDoc.data(),
                      l10n.homeUnnamedItem,
                    ));
        final baseCurrency = normalizeCurrency(
          familySnap.data?.data()?['baseCurrency'] as String?,
          fallback: 'ARS',
        );
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: familyRef
              .collection('expenses')
              .orderBy('occurredAt', descending: true)
              .limit(80)
              .snapshots(),
          builder: (context, expSnap) {
            final monthStart = DateTime(
              DateTime.now().year,
              DateTime.now().month,
              1,
            );
            final monthlyTotalByCurrency = <String, double>{};
            final byCategory = <String, Map<String, double>>{};
            if (expSnap.hasData) {
              for (final doc in expSnap.data!.docs) {
                final d = doc.data();
                if ((d['status'] as String?) == ExpenseLifecycle.cancelled) {
                  continue;
                }
                final amount = expenseAmount(d);
                final currency = expenseCurrency(d, fallback: baseCurrency);
                final key = d['categoryKey'] as String? ?? 'other';
                final occurredAt = (d['occurredAt'] as Timestamp?)?.toDate();
                final categoryTotals = byCategory.putIfAbsent(
                  key,
                  () => <String, double>{},
                );
                categoryTotals[currency] =
                    (categoryTotals[currency] ?? 0) + amount;
                if (occurredAt != null &&
                    !occurredAt.isBefore(monthStart) &&
                    ExpenseLifecycle.countsTowardEffectiveMonthly(d)) {
                  monthlyTotalByCurrency[currency] =
                      (monthlyTotalByCurrency[currency] ?? 0) + amount;
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
                            .where((c) => byCategory.containsKey(c.key))
                            .take(4)
                            .toList();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              l10n.homeActiveHousehold,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: scheme.secondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            SelectableText(
                              householdLabel,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: () => createAndShowFamilyInviteLink(
                                context,
                                familyId,
                              ),
                              child: Text(l10n.homeGenerateInvite),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton(
                              onPressed: onInvites,
                              child: Text(l10n.homeInvitations),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                l10n.homeMonthlyRecognizedExpense,
                                                style: theme
                                                    .textTheme
                                                    .labelLarge
                                                    ?.copyWith(
                                                      color: scheme.secondary,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              ),
                                              const SizedBox(height: 6),
                                              if (monthlyTotalByCurrency
                                                  .isEmpty)
                                                Text(
                                                  l10n.homeNoMonthlyMovements,
                                                  style: theme
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: scheme.primary,
                                                      ),
                                                )
                                              else
                                                ...formatTotalsByCurrency(
                                                  monthlyTotalByCurrency,
                                                  Localizations.localeOf(
                                                    context,
                                                  ),
                                                ).map(
                                                  (line) => Text(
                                                    line,
                                                    style: theme
                                                        .textTheme
                                                        .headlineSmall
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          color: scheme.primary,
                                                        ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        FilledButton.tonalIcon(
                                          onPressed: onOpenExpenses,
                                          icon: const Icon(
                                            Icons.receipt_long_rounded,
                                            size: 20,
                                          ),
                                          label: Text(l10n.homeScan),
                                        ),
                                      ],
                                    ),
                                    if (topChips.isNotEmpty) ...[
                                      const SizedBox(height: 18),
                                      Text(
                                        l10n.homeCategoriesWithMovement,
                                        style: theme.textTheme.labelMedium
                                            ?.copyWith(
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
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 8,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: scheme
                                                      .surfaceContainerHigh,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        999,
                                                      ),
                                                ),
                                                child: Text(
                                                  '${c.label}: ${formatTotalsByCurrency(byCategory[c.key] ?? const <String, double>{}, Localizations.localeOf(context)).join(' · ')}',
                                                  style: theme
                                                      .textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                        color: scheme.secondary,
                                                        fontWeight:
                                                            FontWeight.w700,
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
                                            l10n.homeStockAlerts,
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                  color: scheme.primary,
                                                ),
                                          ),
                                        ),
                                        Icon(
                                          Icons.kitchen_outlined,
                                          color: scheme.secondary,
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      alertCount == 0
                                          ? l10n.homeNoStockAlerts
                                          : l10n.homeStockAlertsToReview(
                                              alertCount,
                                              alertCount == 1 ? '' : 's',
                                            ),
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                          ),
                                    ),
                                    const SizedBox(height: 14),
                                    if (!stockSnap.hasData)
                                      const LinearProgressIndicator(
                                        minHeight: 3,
                                      )
                                    else if (stockDocs.isEmpty)
                                      Text(
                                        l10n.homeAllGoodForNow,
                                        style: theme.textTheme.bodyMedium,
                                      )
                                    else
                                      ...stockDocs.take(3).map((d) {
                                        final s = d.data();
                                        final name =
                                            s['name'] as String? ??
                                            l10n.homeUnnamedItem;
                                        final level = StockLevel.parse(
                                          s['state'] as String?,
                                        );
                                        final dotColor = level
                                            .indicatorDotColor(scheme);
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 10,
                                          ),
                                          child: CozyCard(
                                            color:
                                                scheme.surfaceContainerLowest,
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
                                                        color: dotColor
                                                            .withValues(
                                                              alpha: 0.45,
                                                            ),
                                                        blurRadius: 8,
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        name,
                                                        style: theme
                                                            .textTheme
                                                            .titleSmall
                                                            ?.copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                            ),
                                                      ),
                                                      Text(
                                                        level.label,
                                                        style: theme
                                                            .textTheme
                                                            .labelSmall
                                                            ?.copyWith(
                                                              color: scheme
                                                                  .onSurfaceVariant,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                Icon(
                                                  Icons.add_circle_outline,
                                                  color: scheme.primary,
                                                ),
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
                                        child: Text(l10n.homeViewFullPantry),
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
                                        Icon(
                                          Icons.description_outlined,
                                          color: scheme.primary,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          l10n.homeRecentNote,
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w800,
                                                color: scheme.primary,
                                              ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    if (noteDoc == null)
                                      Text(
                                        l10n.homeNoSharedNotesYet,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                            ),
                                      )
                                    else ...[
                                      CozyCard(
                                        color: scheme.surfaceContainerLow,
                                        padding: const EdgeInsets.all(18),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              noteDoc.data()['title']
                                                      as String? ??
                                                  l10n.homeUntitledNote,
                                              style: theme.textTheme.titleSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w800,
                                                    color: scheme.primary,
                                                  ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              noteDoc.data()['content']
                                                      as String? ??
                                                  '',
                                              maxLines: 4,
                                              overflow: TextOverflow.ellipsis,
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                    color:
                                                        scheme.onSurfaceVariant,
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: scheme.tertiaryContainer,
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                l10n.homeFeaturedRecipe,
                                                style: theme
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(
                                                      color: scheme
                                                          .onTertiaryContainer,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      letterSpacing: 0.8,
                                                    ),
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              featured.titulo,
                                              style: theme
                                                  .textTheme
                                                  .headlineSmall
                                                  ?.copyWith(
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
                                                  l10n.homeMinutes(
                                                    featured.tiempoMin,
                                                  ),
                                                  style: theme
                                                      .textTheme
                                                      .labelMedium
                                                      ?.copyWith(
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
                                                  l10n.homeServings(
                                                    featured.porciones,
                                                  ),
                                                  style: theme
                                                      .textTheme
                                                      .labelMedium
                                                      ?.copyWith(
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
      },
    );
  }
}

/// Paywall y Customer Center de [purchases_ui_flutter] (requiere paywalls en el dashboard RC).
class _RevenueCatUiActions extends StatelessWidget {
  const _RevenueCatUiActions({required this.onRevenueCatStateMayHaveChanged});

  final Future<void> Function() onRevenueCatStateMayHaveChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return CozyCard(
      color: scheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.revenueCatTitle,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.revenueCatDescription,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.payment_rounded),
            label: Text(l10n.revenueCatOpenPaywallPayment),
            onPressed: () =>
                _presentPaywall(context, onRevenueCatStateMayHaveChanged),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: () => _presentCustomerCenter(
                context,
                onRevenueCatStateMayHaveChanged,
              ),
              child: Text(l10n.revenueCatCustomerCenter),
            ),
          ),
        ],
      ),
    );
  }

  static Future<void> _presentPaywall(
    BuildContext context,
    Future<void> Function() onRevenueCatStateMayHaveChanged,
  ) async {
    try {
      await RevenueCatUI.presentPaywall();
      await onRevenueCatStateMayHaveChanged();
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.revenueCatPaywallError('$e'))),
      );
    }
  }

  static Future<void> _presentCustomerCenter(
    BuildContext context,
    Future<void> Function() onRevenueCatStateMayHaveChanged,
  ) async {
    try {
      await RevenueCatUI.presentCustomerCenter();
      await onRevenueCatStateMayHaveChanged();
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.revenueCatCustomerCenterError('$e')),
        ),
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
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final title = switch (state.type) {
      _BillingUiStateType.available => l10n.billingAvailableTitle,
      _BillingUiStateType.notConfigured => l10n.billingNotConfiguredTitle,
      _BillingUiStateType.empty => l10n.billingEmptyTitle,
      _BillingUiStateType.error => l10n.billingErrorTitle,
    };
    final message = switch (state.type) {
      _BillingUiStateType.available => l10n.billingAvailableMessage(
        state.packageCount ?? 0,
      ),
      _BillingUiStateType.notConfigured => l10n.billingNotConfiguredMessage,
      _BillingUiStateType.empty => l10n.billingEmptyMessage,
      _BillingUiStateType.error => l10n.billingErrorMessage,
    };
    final ctaLabel = switch (state.type) {
      _BillingUiStateType.available => l10n.billingRefreshPlans,
      _BillingUiStateType.notConfigured ||
      _BillingUiStateType.error => l10n.billingRetry,
      _BillingUiStateType.empty => l10n.billingRefreshPlans,
    };
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
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.tonal(
              onPressed: onRetry,
              child: Text(ctaLabel),
            ),
          ),
        ],
      ),
    );
  }
}

enum _BillingUiStateType { available, notConfigured, empty, error }

class _BillingUiState {
  const _BillingUiState._({required this.type, this.packageCount});

  const _BillingUiState.available({required int packageCount})
    : this._(type: _BillingUiStateType.available, packageCount: packageCount);

  const _BillingUiState.notConfigured()
    : this._(type: _BillingUiStateType.notConfigured);

  const _BillingUiState.empty() : this._(type: _BillingUiStateType.empty);

  const _BillingUiState.error() : this._(type: _BillingUiStateType.error);

  final _BillingUiStateType type;
  final int? packageCount;
}

class _InviteTokenDialog extends StatefulWidget {
  const _InviteTokenDialog();

  @override
  State<_InviteTokenDialog> createState() => _InviteTokenDialogState();
}

class _InviteTokenDialogState extends State<_InviteTokenDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.inviteDialogTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(hintText: l10n.inviteDialogHint),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          onPressed: () {
            final t = _controller.text.trim();
            Navigator.pop(context, t.isEmpty ? null : t);
          },
          child: Text(l10n.commonContinue),
        ),
      ],
    );
  }
}
