import 'package:craftr_mobile/core/firebase_project.dart';
import 'package:craftr_mobile/core/flavor.dart';
import 'package:craftr_mobile/services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Home provisional: resumen de sesión, hogar activo y accesos a flujos E2.
class BootstrapPage extends StatelessWidget {
  const BootstrapPage({super.key, required this.flavor});

  final AppFlavor flavor;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        body: Center(child: Text('No hay usuario autenticado.')),
      );
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
            'Monorepo listo · flavor=${flavor.name}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (FirebaseProject.isConfigured)
            Text('Firebase project: ${FirebaseProject.projectId}')
          else
            const Text('Sin FIREBASE_PROJECT_ID en dart-define'),
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
                  Text('Usuario: $uid', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Text(
                    familyId != null && familyId.isNotEmpty
                        ? 'Hogar activo: $familyId'
                        : 'Todavía no tenés un hogar activo.',
                    style: Theme.of(context).textTheme.bodyLarge,
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
                    child: const Text('Invitaciones del hogar'),
                  ),
                ],
              );
            },
          ),
          const Divider(height: 32),
          Text(
            'Deep link de invitación (ejemplo): craftr://invite/DEMO_TOKEN',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
