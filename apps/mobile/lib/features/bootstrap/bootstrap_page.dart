import 'package:craftr_mobile/core/firebase_project.dart';
import 'package:craftr_mobile/core/flavor.dart';
import 'package:flutter/material.dart';

/// Root placeholder until feature modules (auth, home, etc.) land.
class BootstrapPage extends StatelessWidget {
  const BootstrapPage({super.key, required this.flavor});

  final AppFlavor flavor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(flavor.displayName)),
      body: Center(
        child: Text(
          'Monorepo listo · flavor=${flavor.name}'
          '${FirebaseProject.isConfigured ? '\nFirebase project: ${FirebaseProject.projectId}' : '\n(Sin FIREBASE_PROJECT_ID en dart-define)'}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}
