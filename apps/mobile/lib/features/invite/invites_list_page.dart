import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:oga/design_system/design_system.dart';
import 'package:oga/features/invite/family_invite_flow.dart';
import 'package:oga/l10n/l10n.dart';
import 'package:oga/services/functions_region.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Lista invitaciones pendientes del hogar activo (solo owners ven acciones).
class InvitesListPage extends StatelessWidget {
  const InvitesListPage({super.key});

  static String _formatExpiry(BuildContext context, dynamic exp) {
    if (exp is Timestamp) {
      final localeTag = Localizations.localeOf(context).toLanguageTag();
      return DateFormat.yMMMd(localeTag).add_Hm().format(exp.toDate());
    }
    return exp?.toString() ?? '—';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Scaffold(body: Center(child: Text(l10n.invitesNoSession)));
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: sanctuaryAppBar(context, title: l10n.invitesListTitle),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }
          final familyId = snap.data!.data()?['activeFamilyId'] as String?;
          if (familyId == null || familyId.isEmpty) {
            return Center(child: Text(l10n.invitesNeedFamily));
          }
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('families')
                .doc(familyId)
                .collection('invites')
                .where('status', isEqualTo: 'pending')
                .orderBy('expiresAt')
                .snapshots(),
            builder: (context, invSnap) {
              if (!invSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = invSnap.data!.docs;
              final bottom = 32 + MediaQuery.paddingOf(context).bottom;
              final top = MediaQuery.paddingOf(context).top + kSanctuaryAppBarToolbarHeight + 8;

              if (docs.isEmpty) {
                return ListView(
                  padding: EdgeInsets.fromLTRB(24, top, 24, bottom),
                  children: [
                    CozyCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l10n.invitesEmptyTitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: scheme.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.invitesEmptyDescription,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () =>
                                createAndShowFamilyInviteLink(context, familyId),
                            child: Text(l10n.homeGenerateInvite),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }
              return ListView(
                padding: EdgeInsets.fromLTRB(24, top, 24, bottom),
                children: [
                  CozyCard(
                    child: Text(
                      l10n.invitesPendingIntro,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...docs.map((d) {
                    final data = d.data();
                    final exp = data['expiresAt'];
                    final expLabel = _formatExpiry(context, exp);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: CozyCard(
                        color: scheme.surfaceContainerLowest,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: scheme.secondaryContainer,
                              child: Icon(
                                Icons.mail_outline_rounded,
                                color: scheme.secondary,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Invitación ${d.id.substring(0, 6)}…',
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    l10n.invitesExpiresLabel(expLabel),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.cancel_outlined),
                              onPressed: () => _revoke(context, familyId, d.id),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: () =>
                        createAndShowFamilyInviteLink(context, familyId),
                    child: Text(l10n.homeGenerateInvite),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  static Future<void> _revoke(
    BuildContext context,
    String familyId,
    String inviteId,
  ) async {
    try {
      final callable = craftrFunctions().httpsCallable('revokeFamilyInvite');
      await callable.call({'familyId': familyId, 'inviteId': inviteId});
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
