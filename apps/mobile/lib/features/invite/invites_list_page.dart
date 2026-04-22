import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:craftr_mobile/services/functions_region.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Lista invitaciones pendientes del hogar activo (solo owners ven acciones).
class InvitesListPage extends StatelessWidget {
  const InvitesListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Sin sesión')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Invitaciones')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream:
            FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snap) {
          if (!snap.hasData || !snap.data!.exists) {
            return const Center(child: CircularProgressIndicator());
          }
          final familyId = snap.data!.data()?['activeFamilyId'] as String?;
          if (familyId == null || familyId.isEmpty) {
            return const Center(child: Text('Primero creá o unite a un hogar.'));
          }
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('families')
                .doc(familyId)
                .collection('invites')
                .where('status', isEqualTo: 'pending')
                .snapshots(),
            builder: (context, invSnap) {
              if (!invSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = invSnap.data!.docs;
              if (docs.isEmpty) {
                return const Center(child: Text('No hay invitaciones pendientes.'));
              }
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final d = docs[i];
                  final data = d.data();
                  final exp = data['expiresAt'];
                  return ListTile(
                    title: Text('Invitación ${d.id.substring(0, 6)}…'),
                    subtitle: Text('Expira: $exp'),
                    trailing: IconButton(
                      icon: const Icon(Icons.cancel_outlined),
                      onPressed: () => _revoke(context, familyId, d.id),
                    ),
                  );
                },
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
