import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:oga/design_system/design_system.dart';
import 'package:oga/l10n/l10n.dart';
import 'package:oga/services/auth_service.dart';

enum _AuthFormMode { signIn, register }

class SignInPage extends StatefulWidget {
  const SignInPage({
    super.key,
    this.emailJustVerified = false,
    this.emailVerificationFailed = false,
    this.pendingEmailVerification = false,
  });

  final bool emailJustVerified;
  final bool emailVerificationFailed;
  final bool pendingEmailVerification;

  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  _AuthFormMode _mode = _AuthFormMode.signIn;
  bool _busy = false;
  bool _obscurePassword = true;
  String? _error;
  bool _registrationSent = false;

  @override
  void initState() {
    super.initState();
    _registrationSent = widget.pendingEmailVerification;
    _hydratePendingVerificationEmail();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      final l10n = context.l10n;
      if (widget.emailJustVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.signInEmailVerifiedSuccess)),
        );
      } else if (widget.emailVerificationFailed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.signInEmailVerificationLinkError)),
        );
      }
    });
  }

  void _hydratePendingVerificationEmail() {
    try {
      final user = _authService.currentUser;
      if (user != null &&
          userRequiresEmailVerification(user) &&
          !user.emailVerified) {
        _emailController.text = user.email ?? '';
      }
    } catch (_) {
      // Firebase may be unavailable in widget tests.
    }
  }

  User? _currentUserOrNull() {
    try {
      return _authService.currentUser;
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

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

  Future<void> _onEmailSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      if (_mode == _AuthFormMode.register) {
        await _authService.registerWithEmailAndPassword(
          email: email,
          password: password,
        );
        if (mounted) {
          setState(() {
            _registrationSent = true;
            _mode = _AuthFormMode.signIn;
          });
        }
      } else {
        await _authService.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
      }
    } on EmailNotVerifiedException {
      if (mounted) {
        setState(() {
          _registrationSent = true;
          _error = context.l10n.signInEmailNotVerified;
        });
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _error = _mapFirebaseAuthError(e));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  String _mapFirebaseAuthError(FirebaseAuthException e) {
    final l10n = context.l10n;
    switch (e.code) {
      case 'invalid-email':
        return l10n.signInInvalidEmail;
      case 'user-disabled':
        return l10n.signInUserDisabled;
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return l10n.signInInvalidCredentials;
      case 'email-already-in-use':
        return l10n.signInEmailAlreadyInUse;
      case 'weak-password':
        return l10n.signInWeakPassword;
      case 'too-many-requests':
        return l10n.signInTooManyRequests;
      default:
        return e.message ?? e.code;
    }
  }

  Future<void> _resendVerification() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _authService.resendVerificationEmail();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.signInVerificationEmailResent)),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _error = e.message ?? e.code);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _signOutPendingVerification() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _authService.signOut();
      if (mounted) {
        setState(() {
          _registrationSent = false;
          _passwordController.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final showPendingVerification = _registrationSent ||
        (widget.pendingEmailVerification && _currentUserOrNull() != null);

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
                          if (showPendingVerification)
                            _PendingVerificationCard(
                              email: _emailController.text.trim().isNotEmpty
                                  ? _emailController.text.trim()
                                  : _currentUserOrNull()?.email ?? '',
                              busy: _busy,
                              onResend: _resendVerification,
                              onUseAnotherAccount: _signOutPendingVerification,
                            )
                          else
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
                                  child: Form(
                                    key: _formKey,
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
                                        const SizedBox(height: 20),
                                        SegmentedButton<_AuthFormMode>(
                                          segments: [
                                            ButtonSegment(
                                              value: _AuthFormMode.signIn,
                                              label: Text(l10n.signInTabSignIn),
                                            ),
                                            ButtonSegment(
                                              value: _AuthFormMode.register,
                                              label: Text(
                                                l10n.signInTabRegister,
                                              ),
                                            ),
                                          ],
                                          selected: {_mode},
                                          onSelectionChanged: _busy
                                              ? null
                                              : (selection) {
                                                  setState(() {
                                                    _mode = selection.first;
                                                    _error = null;
                                                  });
                                                },
                                        ),
                                        const SizedBox(height: 20),
                                        TextFormField(
                                          controller: _emailController,
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          autofillHints: const [
                                            AutofillHints.email,
                                          ],
                                          textInputAction: TextInputAction.next,
                                          decoration: InputDecoration(
                                            labelText: l10n.signInEmailLabel,
                                          ),
                                          validator: (value) {
                                            final trimmed = value?.trim() ?? '';
                                            if (trimmed.isEmpty ||
                                                !trimmed.contains('@')) {
                                              return l10n.signInInvalidEmail;
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 12),
                                        TextFormField(
                                          controller: _passwordController,
                                          obscureText: _obscurePassword,
                                          autofillHints: _mode ==
                                                  _AuthFormMode.signIn
                                              ? const [AutofillHints.password]
                                              : const [
                                                  AutofillHints.newPassword,
                                                ],
                                          decoration: InputDecoration(
                                            labelText:
                                                l10n.signInPasswordLabel,
                                            suffixIcon: IconButton(
                                              onPressed: () {
                                                setState(() {
                                                  _obscurePassword =
                                                      !_obscurePassword;
                                                });
                                              },
                                              icon: Icon(
                                                _obscurePassword
                                                    ? Icons.visibility_outlined
                                                    : Icons
                                                          .visibility_off_outlined,
                                              ),
                                            ),
                                          ),
                                          validator: (value) {
                                            if (value == null ||
                                                value.length < 6) {
                                              return l10n.signInWeakPassword;
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 20),
                                        FilledButton(
                                          onPressed: _busy
                                              ? null
                                              : _onEmailSubmit,
                                          style: FilledButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 16,
                                            ),
                                            shape: const StadiumBorder(),
                                          ),
                                          child: _busy
                                              ? SizedBox(
                                                  height: 24,
                                                  width: 24,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2.5,
                                                    color: scheme.onPrimary,
                                                  ),
                                                )
                                              : Text(
                                                  _mode ==
                                                          _AuthFormMode.register
                                                      ? l10n.signInCreateAccount
                                                      : l10n.signInTabSignIn,
                                                  style: theme
                                                      .textTheme.titleSmall
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color:
                                                            scheme.onPrimary,
                                                      ),
                                                ),
                                        ),
                                        const SizedBox(height: 20),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Divider(
                                                color: scheme.outlineVariant,
                                              ),
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 12,
                                              ),
                                              child: Text(
                                                l10n.signInOrDivider,
                                                style: theme.textTheme.labelSmall
                                                    ?.copyWith(
                                                  color: scheme.outline,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Divider(
                                                color: scheme.outlineVariant,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 20),
                                        FilledButton(
                                          onPressed: _busy ? null : _onGoogle,
                                          style: FilledButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 18,
                                            ),
                                            shape: const StadiumBorder(),
                                            elevation: 4,
                                            shadowColor: scheme.primary
                                                .withValues(alpha: 0.25),
                                          ),
                                          child: Text(
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
                                ),
                              ],
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

class _PendingVerificationCard extends StatelessWidget {
  const _PendingVerificationCard({
    required this.email,
    required this.busy,
    required this.onResend,
    required this.onUseAnotherAccount,
  });

  final String email;
  final bool busy;
  final VoidCallback onResend;
  final VoidCallback onUseAnotherAccount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);

    return CozyCard(
      color: scheme.secondaryContainer.withValues(alpha: 0.35),
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.mark_email_unread_outlined,
            size: 40,
            color: scheme.primary,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.signInCheckEmailTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.signInCheckEmailBody(email),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: busy ? null : onResend,
            child: Text(l10n.signInResendVerification),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: busy ? null : onUseAnotherAccount,
            child: Text(l10n.signInUseAnotherAccount),
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
