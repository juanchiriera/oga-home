import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Estados de stock (producto): hay · queda poco · no hay.
enum StockLevel {
  hay,
  low,
  out;

  String get label => switch (this) {
        StockLevel.hay => 'Hay',
        StockLevel.low => 'Queda poco',
        StockLevel.out => 'No hay',
      };

  static StockLevel parse(String? raw) {
    return StockLevel.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => StockLevel.hay,
    );
  }
}

class StockListPage extends StatelessWidget {
  const StockListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Sin sesión')));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Stock del hogar')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream:
            FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, userSnap) {
          if (!userSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final familyId = userSnap.data!.data()?['activeFamilyId'] as String?;
          if (familyId == null || familyId.isEmpty) {
            return const Center(
              child: Text('Creá o elegí un hogar para ver el stock.'),
            );
          }
          final base = FirebaseFirestore.instance
              .collection('families')
              .doc(familyId)
              .collection('stockItems');
          final query = base.orderBy('name');

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: query.snapshots(),
            builder: (context, q) {
              if (!q.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = q.data!.docs;
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 88),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final d = docs[i];
                  final data = d.data();
                  final name = data['name'] as String? ?? '(sin nombre)';
                  final level = StockLevel.parse(data['state'] as String?);
                  return ListTile(
                    title: Text(name),
                    subtitle: Text(level.label),
                    trailing: PopupMenuButton<String>(
                      onSelected: (action) async {
                        if (action == 'edit') {
                          await _editItem(context, familyId, d.id, name, level);
                        } else if (action == 'delete') {
                          await base.doc(d.id).delete();
                        }
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'edit', child: Text('Editar')),
                        PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addItem(context),
        icon: const Icon(Icons.add),
        label: const Text('Ítem'),
      ),
    );
  }

  static Future<void> _addItem(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return;
    }
    final user = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final familyId = user.data()?['activeFamilyId'] as String?;
    if (familyId == null || familyId.isEmpty || !context.mounted) {
      return;
    }
    var name = '';
    var level = StockLevel.hay;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: const Text('Nuevo ítem'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  onChanged: (v) => name = v,
                ),
                const SizedBox(height: 12),
                Text('Estado', style: Theme.of(ctx).textTheme.labelLarge),
                SegmentedButton<StockLevel>(
                  segments: StockLevel.values
                      .map((e) => ButtonSegment(value: e, label: Text(e.label)))
                      .toList(),
                  selected: {level},
                  onSelectionChanged: (s) =>
                      setLocal(() => level = s.first),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
            ],
          );
        },
      ),
    );
    if (ok != true || name.trim().isEmpty || !context.mounted) {
      return;
    }
    await FirebaseFirestore.instance
        .collection('families')
        .doc(familyId)
        .collection('stockItems')
        .add({
      'name': name.trim(),
      'state': level.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  static Future<void> _editItem(
    BuildContext context,
    String familyId,
    String itemId,
    String currentName,
    StockLevel current,
  ) async {
    var name = currentName;
    var level = current;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: const Text('Editar ítem'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  initialValue: currentName,
                  decoration: const InputDecoration(labelText: 'Nombre'),
                  onChanged: (v) => name = v,
                ),
                const SizedBox(height: 12),
                Text('Estado', style: Theme.of(ctx).textTheme.labelLarge),
                SegmentedButton<StockLevel>(
                  segments: StockLevel.values
                      .map((e) => ButtonSegment(value: e, label: Text(e.label)))
                      .toList(),
                  selected: {level},
                  onSelectionChanged: (s) =>
                      setLocal(() => level = s.first),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
            ],
          );
        },
      ),
    );
    if (ok != true || name.trim().isEmpty || !context.mounted) {
      return;
    }
    await FirebaseFirestore.instance
        .collection('families')
        .doc(familyId)
        .collection('stockItems')
        .doc(itemId)
        .update({
      'name': name.trim(),
      'state': level.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
