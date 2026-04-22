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
          'Monorepo listo · flavor=${flavor.name}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}
