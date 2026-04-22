import 'package:craftr_mobile/core/firebase_project.dart';
import 'package:craftr_mobile/core/flavor.dart';
import 'package:craftr_mobile/services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HomeDashboardPage extends StatelessWidget {
  const HomeDashboardPage({super.key, required this.flavor});

  final AppFlavor flavor;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Sin sesión')));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(flavor.displayName),
        actions: [
          TextButton(
            onPressed: () async {
              await AuthService().signOut();
              if (context.mounted) {
                context.go('/sign-in');
              }
            },
            child: const Text('Salir'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Resumen del hogar',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          if (FirebaseProject.isConfigured)
            Text('Firebase: ${FirebaseProject.projectId}')
          else
            const Text('Configurá FIREBASE_PROJECT_ID (dart-define).'),
          const Divider(height: 32),
          StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream:
                FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final data = snap.data!.data();
              final familyId = data?['activeFamilyId'] as String?;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    familyId != null && familyId.isNotEmpty
                        ? 'Hogar activo: $familyId'
                        : 'Sin hogar activo todavía.',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => context.push('/create-family'),
                    child: const Text('Crear hogar'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: familyId == null || familyId.isEmpty
                        ? null
                        : () => context.push('/invites'),
                    child: const Text('Invitaciones'),
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
