import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:craftr_mobile/design_system/design_system.dart';
import 'package:craftr_mobile/services/functions_region.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Lista invitaciones pendientes del hogar activo (solo owners ven acciones).
class InvitesListPage extends StatelessWidget {
  const InvitesListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Sin sesión')));
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: sanctuaryAppBar(context, title: 'Invitaciones'),
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
            return const Center(
              child: Text('Primero creá o unite a un hogar.'),
            );
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
              if (docs.isEmpty) {
                return const Center(
                  child: Text('No hay invitaciones pendientes.'),
                );
              }
              return ListView(
                padding: EdgeInsets.fromLTRB(
                  24,
                  MediaQuery.paddingOf(context).top + kToolbarHeight + 8,
                  24,
                  32 + MediaQuery.paddingOf(context).bottom,
                ),
                children: [
                  CozyCard(
                    child: Text(
                      'Invitaciones pendientes para sumar miembros al hogar.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...docs.map((d) {
                    final data = d.data();
                    final exp = data['expiresAt'];
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
                                    'Expira: $exp',
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
