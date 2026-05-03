import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

/// Logo de marca (`assets/branding/app_logo.png`), alineado con la paleta del design system.
class AppBrandLogo extends StatelessWidget {
  const AppBrandLogo({super.key, this.height = 32});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/branding/app_logo.png',
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      semanticLabel: 'Oga',
    );
  }
}

/// Horizontal padding aligned with `docs/pantallas` stitch layouts (24–32px).
const EdgeInsets kSanctuaryScreenPadding = EdgeInsets.symmetric(horizontal: 24);

/// Debe coincidir con [sanctuaryAppBar] `toolbarHeight`.
const double kSanctuaryAppBarToolbarHeight = 100;

/// Extra scroll padding so content clears [SanctuaryBottomNav] + safe area.
double sanctuaryScrollBottomPadding(BuildContext context) =>
    108 + MediaQuery.paddingOf(context).bottom;

/// Vertical extent where list content scrolls under [sanctuaryAppBar].
double sanctuaryAppBarScrollFadeHeight(BuildContext context) =>
    MediaQuery.paddingOf(context).top + kSanctuaryAppBarToolbarHeight + 24;

/// Soft mask so scrolled content fades under the frosted app bar.
class SanctuaryScrollUnderAppBarFade extends StatelessWidget {
  const SanctuaryScrollUnderAppBarFade({
    super.key,
    required this.child,
    this.fadeHeight,
  });

  final Widget child;
  final double? fadeHeight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final h = fadeHeight ?? sanctuaryAppBarScrollFadeHeight(context);
    final base = Theme.of(context).scaffoldBackgroundColor;
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: h,
            width: double.infinity,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.lerp(
                        base,
                        scheme.surface,
                        0.35,
                      )!.withValues(alpha: 1),
                      base.withValues(alpha: 0.5),
                      base.withValues(alpha: 0),
                    ],
                    stops: const [0.2, 0.57, 1.0],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Gradient above the bottom [NavigationBar]: content tucks behind while scrolling.
class SanctuaryNavBarScrollFade extends StatelessWidget {
  const SanctuaryNavBarScrollFade({super.key});

  static const double height = 100;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).scaffoldBackgroundColor;
    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  base,
                  base.withValues(alpha: 0.88),
                  base.withValues(alpha: 0),
                ],
                stops: const [0.0, 0.38, 1.0],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared FAB spacing token to keep distance from [SanctuaryBottomNav].
const double kSanctuaryFabBottomOffset = 72;

/// Bottom inset for FABs that keeps them above nav/safe area and keyboard.
double sanctuaryFabBottomInset(BuildContext context) {
  final mediaQuery = MediaQuery.of(context);
  return kSanctuaryFabBottomOffset +
      math.max(mediaQuery.padding.bottom, mediaQuery.viewInsets.bottom);
}

/// Frosted app bar matching dashboard / despensa / notas references.
PreferredSizeWidget sanctuaryAppBar(
  BuildContext context, {
  String title = 'Oga',
  Widget? leading,
  List<Widget>? actions,
  bool centerTitle = true,
}) {
  final scheme = Theme.of(context).colorScheme;
  final theme = Theme.of(context);
  return AppBar(
    toolbarHeight: kSanctuaryAppBarToolbarHeight,
    leading: leading,
    automaticallyImplyLeading: leading == null,
    title: Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const AppBrandLogo(height: 52),
        const SizedBox(height: 6),
        Text(
          title,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge?.copyWith(
            fontStyle: FontStyle.normal,
            fontWeight: FontWeight.w800,
            color: scheme.primary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'the housekeeper',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 14,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w500,
            color: scheme.primary.withValues(alpha: 0.9),
            letterSpacing: 0.3,
            height: 1.0,
          ),
        ),
      ],
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
                    child: Semantics(
                      button: true,
                      selected: selected,
                      label: d.label,
                      onTapHint: 'Abrir ${d.label}',
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          minHeight: kMinInteractiveDimension,
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(999),
                          onTap: () => onSelect(i),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                curve: Curves.easeOutCubic,
                                width: selected ? 52 : 48,
                                height: selected ? 52 : 48,
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
                                  size: selected ? 26 : 24,
                                  color: selected
                                      ? scheme.onPrimary
                                      : scheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                d.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      fontWeight: selected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: selected
                                          ? scheme.primary
                                          : scheme.onSurfaceVariant,
                                      fontSize: 10.5,
                                      letterSpacing: 0.2,
                                    ),
                              ),
                            ],
                          ),
                        ),
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
