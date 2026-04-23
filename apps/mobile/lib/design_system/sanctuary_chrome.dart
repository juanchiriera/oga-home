import 'dart:ui';

import 'package:flutter/material.dart';

/// Horizontal padding aligned with `docs/pantallas` stitch layouts (24–32px).
const EdgeInsets kSanctuaryScreenPadding = EdgeInsets.symmetric(horizontal: 24);

/// Extra scroll padding so content clears [SanctuaryBottomNav] + safe area.
double sanctuaryScrollBottomPadding(BuildContext context) =>
    108 + MediaQuery.paddingOf(context).bottom;

/// Frosted app bar matching dashboard / despensa / notas references.
PreferredSizeWidget sanctuaryAppBar(
  BuildContext context, {
  String title = 'Sanctuary',
  Widget? leading,
  List<Widget>? actions,
  bool centerTitle = true,
}) {
  final scheme = Theme.of(context).colorScheme;
  return AppBar(
    leading: leading,
    automaticallyImplyLeading: leading == null,
    title: Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.w800,
        color: scheme.primary,
        letterSpacing: -0.5,
      ),
    ),
    centerTitle: centerTitle,
    actions: actions,
    flexibleSpace: ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface.withValues(alpha: 0.82),
            boxShadow: [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.05),
                blurRadius: 30,
                offset: const Offset(0, 8),
              ),
            ],
          ),
        ),
      ),
    ),
    backgroundColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
  );
}

/// Hero strip: primary → primaryContainer gradient (dashboard reference).
class SanctuaryAssistantHero extends StatelessWidget {
  const SanctuaryAssistantHero({
    super.key,
    required this.greetingLine,
    required this.subtitle,
    this.badgeLabel = 'Asistente del hogar',
  });

  final String greetingLine;
  final String subtitle;
  final String badgeLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final onPrimary = scheme.onPrimary;
    final theme = Theme.of(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [scheme.primary, scheme.primaryContainer],
                ),
              ),
            ),
          ),
          Positioned(
            right: -48,
            top: -48,
            child: IgnorePointer(
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.tertiaryContainer.withValues(alpha: 0.28),
                ),
              ),
            ),
          ),
          Positioned(
            right: 28,
            bottom: -36,
            child: IgnorePointer(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: scheme.secondaryContainer.withValues(alpha: 0.18),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 20,
                      color: const Color(0xFFFFDDB3).withValues(alpha: 0.95),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        badgeLabel,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: onPrimary.withValues(alpha: 0.85),
                          letterSpacing: 1.0,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  greetingLine,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: onPrimary,
                    fontWeight: FontWeight.w800,
                    height: 1.12,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: onPrimary.withValues(alpha: 0.92),
                    height: 1.45,
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

/// Floating bottom bar with blur (dashboard_principal bottom nav reference).
class SanctuaryBottomNav extends StatelessWidget {
  const SanctuaryBottomNav({
    super.key,
    required this.currentIndex,
    required this.onSelect,
    required this.destinations,
  });

  final int currentIndex;
  final ValueChanged<int> onSelect;
  final List<SanctuaryBottomDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 12 + bottomInset),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.72),
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.07),
                  blurRadius: 40,
                  offset: const Offset(0, -10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(destinations.length, (i) {
                  final d = destinations[i];
                  final selected = i == currentIndex;
                  return Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: () => onSelect(i),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            width: selected ? 52 : 40,
                            height: selected ? 52 : 40,
                            decoration: BoxDecoration(
                              color: selected
                                  ? scheme.primary
                                  : Colors.transparent,
                              shape: BoxShape.circle,
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color: scheme.primary.withValues(
                                          alpha: 0.35,
                                        ),
                                        blurRadius: 18,
                                        offset: const Offset(0, 6),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Icon(
                              selected ? d.selectedIcon : d.icon,
                              size: selected ? 26 : 22,
                              color: selected
                                  ? scheme.onPrimary
                                  : scheme.secondary.withValues(alpha: 0.55),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            d.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              fontWeight:
                                  selected ? FontWeight.w700 : FontWeight.w500,
                              color: selected
                                  ? scheme.primary
                                  : scheme.secondary.withValues(alpha: 0.55),
                              fontSize: 10.5,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SanctuaryBottomDestination {
  const SanctuaryBottomDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}
