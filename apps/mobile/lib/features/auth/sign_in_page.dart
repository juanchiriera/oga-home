import 'package:oga/design_system/design_system.dart';
import 'package:oga/l10n/l10n.dart';
import 'package:oga/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _authService = AuthService();
  bool _busy = false;
  String? _error;

  Future<void> _onGoogle() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _authService.signInWithGoogle();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
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
    context.go('/invite/$path');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            bottom: -96,
            left: -96,
            child: IgnorePointer(
              child: Transform.rotate(
                angle: 0.79,
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(48),
                    color: scheme.primaryContainer.withValues(alpha: 0.08),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.sizeOf(context).height * 0.22,
            right: -120,
            child: IgnorePointer(
              child: Transform.rotate(
                angle: -0.21,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(56),
                    color: scheme.tertiaryContainer.withValues(alpha: 0.08),
                  ),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(48),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: scheme.shadow.withValues(alpha: 0.05),
                      blurRadius: 50,
                      offset: const Offset(0, 20),
                    ),
                  ],
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(32, 14, 32, 22),
                    child: Row(
                      children: [
                        const AppBrandLogo(height: 40),
                        const SizedBox(width: 12),
                        Text(
                          l10n.signInBrand,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: scheme.primary,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l10n.signInWelcomeTitle,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: scheme.primary,
                              letterSpacing: -0.8,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            l10n.signInWelcomeSubtitle,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: scheme.secondary,
                              fontWeight: FontWeight.w500,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                top: -40,
                                right: -40,
                                child: IgnorePointer(
                                  child: Container(
                                    width: 160,
                                    height: 160,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: scheme.secondaryContainer
                                          .withValues(alpha: 0.2),
                                    ),
                                  ),
                                ),
                              ),
                              CozyCard(
                                color: scheme.surfaceContainerLow,
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      l10n.signInAccessCardTitle,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: scheme.primary,
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      l10n.signInAccessCardDescription,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: scheme.onSurfaceVariant,
                                            height: 1.5,
                                          ),
                                    ),
                                    const SizedBox(height: 28),
                                    FilledButton(
                                      onPressed: _busy ? null : _onGoogle,
                                      style: FilledButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 18,
                                        ),
                                        shape: const StadiumBorder(),
                                        elevation: 4,
                                        shadowColor: scheme.primary.withValues(
                                          alpha: 0.25,
                                        ),
                                      ),
                                      child: _busy
                                          ? SizedBox(
                                              height: 24,
                                              width: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                color: scheme.onPrimary,
                                              ),
                                            )
                                          : Text(
                                              l10n.signInContinueWithGoogle,
                                              style: theme.textTheme.titleSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                    color: scheme.onPrimary,
                                                  ),
                                            ),
                                    ),
                                    if (_error != null) ...[
                                      const SizedBox(height: 16),
                                      Text(
                                        _error!,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(color: scheme.error),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: scheme.tertiaryContainer.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: scheme.tertiaryContainer.withValues(
                                  alpha: 0.28,
                                ),
                                width: 2,
                                strokeAlign: BorderSide.strokeAlignInside,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: scheme.tertiaryContainer,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: scheme.shadow.withValues(
                                            alpha: 0.12,
                                          ),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Icon(
                                        Icons.group_add_rounded,
                                        color: scheme.onTertiaryContainer,
                                        size: 28,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 14),
                                  Text(
                                    l10n.signInJoinExistingHomeTitle,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: scheme.tertiary,
                                        ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    l10n.signInJoinExistingHomeDescription,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      height: 1.45,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  FilledButton(
                                    onPressed: () => _openInviteRedeem(context),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: scheme.tertiary,
                                      foregroundColor: scheme.onTertiary,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 28,
                                        vertical: 14,
                                      ),
                                      shape: const StadiumBorder(),
                                    ),
                                    child: Text(l10n.signInRedeemCode),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _FooterGlyph(
                                icon: Icons.spa_rounded,
                                scheme: scheme,
                              ),
                              const SizedBox(width: 16),
                              _FooterGlyph(
                                icon: Icons.energy_savings_leaf_rounded,
                                scheme: scheme,
                              ),
                              const SizedBox(width: 16),
                              _FooterGlyph(
                                icon: Icons.eco_rounded,
                                scheme: scheme,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            l10n.signInFooterTagline,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: scheme.outline,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FooterGlyph extends StatelessWidget {
  const _FooterGlyph({required this.icon, required this.scheme});

  final IconData icon;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: scheme.primaryContainer, size: 24),
    );
  }
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
