import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:oga/core/entitlements_scope.dart';
import 'package:oga/core/monetization.dart';
import 'package:oga/design_system/design_system.dart';
import 'package:oga/features/expenses/expense_money.dart';
import 'package:oga/features/invite/family_invite_flow.dart';
import 'package:oga/features/profile/account_preferences.dart';
import 'package:oga/l10n/l10n.dart';
import 'package:oga/services/auth_service.dart';
import 'package:oga/services/purchases_service.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

final Uri _accountDeletionWebUri = Uri.parse(
  'https://oga-home.web.app/account-deletion/',
);

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _authService = AuthService();
  final _purchasesService = PurchasesService();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  Future<_BillingUiState>? _billingState;
  String _selectedLocaleCode = 'es';
  List<String> _selectedCurrencyCodes = const [];
  bool _isSaving = false;
  bool _isSavingPreferences = false;
  bool _isSigningOut = false;
  bool _deletingAccount = false;
  bool _didInitValues = false;

  @override
  void initState() {
    super.initState();
    _billingState = _loadBillingState();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<_BillingUiState> _loadBillingState() async {
    if (!MonetizationConfig.billingLive || !_purchasesService.isConfigured) {
      return const _BillingUiState.notConfigured();
    }
    try {
      final offerings = await _purchasesService.fetchOfferings();
      final packageCount = offerings?.current?.availablePackages.length ?? 0;
      if (packageCount <= 0) {
        return const _BillingUiState.empty();
      }
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

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Sin sesión activa')));
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: sanctuaryAppBar(
        context,
        title: _copy(
          context,
          es: 'Configuración de usuario',
          en: 'User settings',
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? <String, dynamic>{};
          final displayName =
              (data['displayName'] as String?) ??
              user.displayName ??
              user.email?.split('@').first ??
              'Usuario';
          final photoUrl = (data['photoUrl'] as String?) ?? user.photoURL ?? '';
          final email = user.email ?? (data['email'] as String?) ?? '';
          final familyId = data['activeFamilyId'] as String?;

          if (!_didInitValues) {
            _nameController.text = displayName;
            final locale = Localizations.localeOf(context);
            final storedLocaleCode = data['preferredLocale'] as String?;
            _selectedLocaleCode =
                kSupportedAccountLocaleCodes.contains(storedLocaleCode)
                ? storedLocaleCode!
                : accountLocaleCodeFromLocale(locale);
            _selectedCurrencyCodes = normalizeAccountCurrencies(
              data['currencyCodes'] is Iterable
                  ? (data['currencyCodes'] as Iterable)
                  : null,
              fallbackLocale: locale,
            );
            _didInitValues = true;
          }

          final l10n = context.l10n;
          return Stack(
            children: [
              ListView(
                padding: EdgeInsets.fromLTRB(
                  24,
                  MediaQuery.paddingOf(context).top +
                      kSanctuaryAppBarToolbarHeight +
                      8,
                  24,
                  32 + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  _ProfileHeader(
                    displayName: _nameController.text.trim().isEmpty
                        ? displayName
                        : _nameController.text.trim(),
                    photoUrl: photoUrl,
                  ),
                  const SizedBox(height: 24),
                  CozyCard(
                    color: Theme.of(context).colorScheme.surfaceContainerLowest,
                    padding: const EdgeInsets.all(20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            _copy(
                              context,
                              es: 'Datos de la cuenta',
                              en: 'Account details',
                            ),
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _nameController,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: _copy(
                                context,
                                es: 'Nombre',
                                en: 'Name',
                              ),
                              hintText: 'Ej: Sarah Jenkins',
                            ),
                            onChanged: (_) => setState(() {}),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return _copy(
                                  context,
                                  es: 'Ingresá un nombre',
                                  en: 'Enter a name',
                                );
                              }
                              return null;
                            },
                          ),
                          if (email.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _InfoRow(
                              icon: Icons.mail_outline_rounded,
                              label: _copy(context, es: 'Correo', en: 'Email'),
                              value: email,
                            ),
                          ],
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: _isSaving ? null : _saveProfile,
                            icon: _isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.save_outlined),
                            label: Text(
                              _isSaving
                                  ? _copy(
                                      context,
                                      es: 'Guardando...',
                                      en: 'Saving...',
                                    )
                                  : _copy(
                                      context,
                                      es: 'Guardar nombre',
                                      en: 'Save name',
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _FamilySettingsSection(familyId: familyId),
                  const SizedBox(height: 20),
                  _BillingSettingsSection(
                    billingState: _billingState,
                    onRefresh: _refreshBillingState,
                  ),
                  const SizedBox(height: 20),
                  _PreferencesSection(
                    selectedLocaleCode: _selectedLocaleCode,
                    selectedCurrencyCodes: _selectedCurrencyCodes,
                    isSaving: _isSavingPreferences,
                    onLocaleChanged: (value) {
                      setState(() => _selectedLocaleCode = value);
                    },
                    onCurrencyToggled: _toggleCurrency,
                    onSave: _savePreferences,
                  ),
                  const SizedBox(height: 20),
                  _SessionSection(
                    isSigningOut: _isSigningOut,
                    onSignOut: _signOut,
                  ),
                  const SizedBox(height: 20),
                  CozyCard(
                    color: Theme.of(context).colorScheme.surfaceContainerLowest,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.profileDeleteAccountSectionTitle,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).colorScheme.error,
                              ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          l10n.profileDeleteAccountDescription,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: (_isSaving || _deletingAccount)
                                ? null
                                : _openAccountDeletionWebPage,
                            icon: const Icon(
                              Icons.open_in_new_rounded,
                              size: 20,
                            ),
                            label: Text(l10n.profileDeleteAccountWebLink),
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: (_isSaving || _deletingAccount)
                              ? null
                              : _confirmAndDeleteAccount,
                          icon: const Icon(Icons.delete_forever_outlined),
                          label: Text(l10n.profileDeleteAccountButton),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Theme.of(
                              context,
                            ).colorScheme.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_deletingAccount)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.35),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              l10n.profileDeleteAccountInProgress,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openAccountDeletionWebPage() async {
    final ok = await launchUrl(
      _accountDeletionWebUri,
      mode: LaunchMode.externalApplication,
    );
    if (!mounted) {
      return;
    }
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo abrir el enlace. Probá desde el navegador.',
          ),
        ),
      );
    }
  }

  Future<void> _confirmAndDeleteAccount() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.profileDeleteAccountConfirmTitle),
          content: Text(l10n.profileDeleteAccountConfirmBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.commonCancel),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(dialogContext).colorScheme.error,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.profileDeleteAccountConfirmAction),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) {
      return;
    }

    setState(() => _deletingAccount = true);
    try {
      await _authService.deleteAccountWithGoogleReauthentication();
    } on StateError catch (e) {
      if (!mounted) {
        return;
      }
      final cancelled = e.toString().contains('Google sign-in cancelled');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cancelled
                ? context.l10n.profileDeleteAccountCancelled
                : context.l10n.profileDeleteAccountError(e.toString()),
          ),
        ),
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.profileDeleteAccountError(e.message ?? e.code),
          ),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.profileDeleteAccountError(e.message ?? e.code),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.profileDeleteAccountError(e.toString())),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _deletingAccount = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _isSaving = true);
    try {
      await _authService.updateProfile(displayName: _nameController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _copy(context, es: 'Perfil actualizado', en: 'Profile updated'),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _copy(
              context,
              es: 'No se pudo actualizar el perfil. Intentá nuevamente.',
              en: 'Could not update your profile. Try again.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _toggleCurrency(String currency, bool selected) {
    final next = [..._selectedCurrencyCodes];
    if (selected) {
      if (!next.contains(currency)) {
        next.add(currency);
      }
    } else if (next.length > 1) {
      next.remove(currency);
    }
    setState(() => _selectedCurrencyCodes = next);
  }

  Future<void> _savePreferences() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return;
    }
    final locale = accountLocaleFromCode(_selectedLocaleCode);
    final currencies = normalizeAccountCurrencies(
      _selectedCurrencyCodes,
      fallbackLocale: locale,
    );
    setState(() {
      _isSavingPreferences = true;
      _selectedCurrencyCodes = currencies;
    });
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'preferredLocale': _selectedLocaleCode,
        'currencyCodes': currencies,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _copy(
              context,
              es: 'Preferencias actualizadas',
              en: 'Preferences updated',
            ),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _copy(
              context,
              es: 'No se pudieron guardar las preferencias.',
              en: 'Could not save preferences.',
            ),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSavingPreferences = false);
      }
    }
  }

  Future<void> _signOut() async {
    setState(() => _isSigningOut = true);
    try {
      await _authService.signOut();
      if (mounted) {
        context.go('/sign-in');
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isSigningOut = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _copy(
              context,
              es: 'No se pudo cerrar sesión. Intentá nuevamente.',
              en: 'Could not sign out. Try again.',
            ),
          ),
        ),
      );
    }
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.displayName, required this.photoUrl});

  final String displayName;
  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CozyCard(
      color: scheme.surfaceContainerLow,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Center(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                _AvatarCircle(displayName: displayName, photoUrl: photoUrl),
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: scheme.shadow.withValues(alpha: 0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        Icons.edit_rounded,
                        size: 16,
                        color: scheme.onPrimary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            displayName,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            _copy(
              context,
              es: 'Configuración de cuenta y hogar',
              en: 'Account and household settings',
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: scheme.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: scheme.secondary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: scheme.secondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(value, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _FamilySettingsSection extends StatelessWidget {
  const _FamilySettingsSection({required this.familyId});

  final String? familyId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final activeFamilyId = familyId;
    return CozyCard(
      color: scheme.surfaceContainerLowest,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle(
            icon: Icons.group_outlined,
            title: _copy(context, es: 'Gestión de familia', en: 'Family'),
          ),
          const SizedBox(height: 12),
          if (activeFamilyId == null || activeFamilyId.isEmpty) ...[
            Text(
              _copy(
                context,
                es: 'Creá un hogar o canjeá una invitación para sumarte a uno.',
                en: 'Create a household or redeem an invitation to join one.',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () => context.push('/create-family'),
              icon: const Icon(Icons.home_work_outlined),
              label: Text(
                _copy(context, es: 'Crear hogar', en: 'Create household'),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => promptAndOpenFamilyInvite(context),
              icon: const Icon(Icons.mark_email_unread_outlined),
              label: Text(
                _copy(context, es: 'Canjear invitación', en: 'Redeem invite'),
              ),
            ),
          ] else
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('families')
                  .doc(activeFamilyId)
                  .snapshots(),
              builder: (context, snapshot) {
                final name = (snapshot.data?.data()?['name'] as String?)
                    ?.trim();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      name == null || name.isEmpty
                          ? _copy(
                              context,
                              es: 'Hogar activo',
                              en: 'Active household',
                            )
                          : name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _copy(
                        context,
                        es: 'Enviá invitaciones y revisá las pendientes desde este apartado.',
                        en: 'Send invites and review pending invitations here.',
                      ),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => createAndShowFamilyInviteLink(
                        context,
                        activeFamilyId,
                      ),
                      icon: const Icon(Icons.person_add_alt_1_outlined),
                      label: Text(
                        _copy(
                          context,
                          es: 'Enviar invitación',
                          en: 'Send invite',
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () => context.push('/invites'),
                      icon: const Icon(Icons.mail_outline_rounded),
                      label: Text(
                        _copy(
                          context,
                          es: 'Ver invitaciones',
                          en: 'View invitations',
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _BillingSettingsSection extends StatelessWidget {
  const _BillingSettingsSection({
    required this.billingState,
    required this.onRefresh,
  });

  final Future<_BillingUiState>? billingState;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CozyCard(
      color: scheme.surfaceContainerLowest,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle(
            icon: Icons.workspace_premium_outlined,
            title: _copy(context, es: 'Suscripciones', en: 'Subscriptions'),
          ),
          const SizedBox(height: 12),
          FutureBuilder<_BillingUiState>(
            future: billingState,
            builder: (context, snapshot) {
              final state = snapshot.data;
              if (snapshot.connectionState == ConnectionState.waiting &&
                  state == null) {
                return const Center(child: CircularProgressIndicator());
              }
              return _BillingStateCard(
                state: state ?? const _BillingUiState.notConfigured(),
                onRetry: onRefresh,
              );
            },
          ),
          if (MonetizationConfig.billingLive) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => _presentCustomerCenter(context, onRefresh),
              icon: const Icon(Icons.receipt_long_outlined),
              label: Text(context.l10n.revenueCatCustomerCenter),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _presentPaywall(context, onRefresh),
              icon: const Icon(Icons.payment_rounded),
              label: Text(context.l10n.revenueCatOpenPaywallPayment),
            ),
          ],
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
      if (context.mounted) {
        await MainShellEntitlementsScope.refresh(context);
      }
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
      if (context.mounted) {
        await MainShellEntitlementsScope.refresh(context);
      }
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: switch (state.type) {
          _BillingUiStateType.available => scheme.primaryContainer,
          _BillingUiStateType.error => scheme.errorContainer,
          _BillingUiStateType.notConfigured => scheme.surfaceContainer,
          _BillingUiStateType.empty => scheme.surfaceContainerHigh,
        },
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
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

class _PreferencesSection extends StatelessWidget {
  const _PreferencesSection({
    required this.selectedLocaleCode,
    required this.selectedCurrencyCodes,
    required this.isSaving,
    required this.onLocaleChanged,
    required this.onCurrencyToggled,
    required this.onSave,
  });

  final String selectedLocaleCode;
  final List<String> selectedCurrencyCodes;
  final bool isSaving;
  final ValueChanged<String> onLocaleChanged;
  final void Function(String currency, bool selected) onCurrencyToggled;
  final Future<void> Function() onSave;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final saveButtonTextColor =
        FilledButtonTheme.of(
          context,
        ).style?.foregroundColor?.resolve(<WidgetState>{}) ??
        scheme.onPrimary;
    return CozyCard(
      color: scheme.surfaceContainerLowest,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle(
            icon: Icons.tune_rounded,
            title: _copy(context, es: 'Preferencias', en: 'Preferences'),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: selectedLocaleCode,
            decoration: InputDecoration(
              labelText: _copy(context, es: 'Idioma', en: 'Language'),
            ),
            items: [
              DropdownMenuItem(
                value: 'es',
                child: Text(_copy(context, es: 'Castellano', en: 'Spanish')),
              ),
              DropdownMenuItem(
                value: 'en',
                child: Text(_copy(context, es: 'Inglés', en: 'English')),
              ),
            ],
            onChanged: isSaving
                ? null
                : (value) => onLocaleChanged(value ?? selectedLocaleCode),
          ),
          const SizedBox(height: 18),
          Text(
            _copy(context, es: 'Divisas', en: 'Currencies'),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _copy(
              context,
              es: 'Elegí las divisas que querés usar al cargar gastos.',
              en: 'Choose the currencies available when entering expenses.',
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final currency in kSupportedCurrencies)
                FilterChip(
                  label: Text(currency),
                  selected: selectedCurrencyCodes.contains(currency),
                  labelStyle: selectedCurrencyCodes.contains(currency)
                      ? TextStyle(color: saveButtonTextColor)
                      : null,
                  onSelected: isSaving
                      ? null
                      : (selected) => onCurrencyToggled(currency, selected),
                ),
            ],
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: isSaving ? null : onSave,
            icon: isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(
              isSaving
                  ? _copy(context, es: 'Guardando...', en: 'Saving...')
                  : _copy(
                      context,
                      es: 'Guardar preferencias',
                      en: 'Save preferences',
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionSection extends StatelessWidget {
  const _SessionSection({required this.isSigningOut, required this.onSignOut});

  final bool isSigningOut;
  final Future<void> Function() onSignOut;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CozyCard(
      color: scheme.surfaceContainerLowest,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionTitle(
            icon: Icons.logout_rounded,
            title: _copy(context, es: 'Sesión', en: 'Session'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: isSigningOut ? null : onSignOut,
            icon: isSigningOut
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.logout_rounded),
            label: Text(
              isSigningOut
                  ? _copy(context, es: 'Cerrando...', en: 'Signing out...')
                  : _copy(context, es: 'Cerrar sesión', en: 'Sign out'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, color: scheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: scheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}

String _copy(BuildContext context, {required String es, required String en}) {
  return Localizations.localeOf(context).languageCode == 'en' ? en : es;
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({required this.displayName, required this.photoUrl});

  final String displayName;
  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    const size = 112.0;
    final hasPhoto = photoUrl.trim().isNotEmpty;
    final initials = _buildInitials(displayName);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.secondaryContainer,
      ),
      child: hasPhoto
          ? Image.network(
              photoUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _InitialsFallback(initials: initials),
            )
          : _InitialsFallback(initials: initials),
    );
  }

  String _buildInitials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.isEmpty) return 'U';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    final first = parts.first.substring(0, 1);
    final last = parts.last.substring(0, 1);
    return (first + last).toUpperCase();
  }
}

class _InitialsFallback extends StatelessWidget {
  const _InitialsFallback({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.secondaryContainer,
      child: Center(
        child: Text(
          initials,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: scheme.onSecondaryContainer,
          ),
        ),
      ),
    );
  }
}
