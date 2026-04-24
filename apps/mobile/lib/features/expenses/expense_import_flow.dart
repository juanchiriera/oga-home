import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:craftr_mobile/services/functions_region.dart';

const _categoryChoices = <MapEntry<String, String>>[
  MapEntry('housing', 'Vivienda'),
  MapEntry('food', 'Comida'),
  MapEntry('transport', 'Transporte'),
  MapEntry('shopping', 'Compras'),
  MapEntry('utilities', 'Servicios'),
  MapEntry('health', 'Salud'),
  MapEntry('education', 'Educación'),
  MapEntry('leisure', 'Ocio'),
  MapEntry('other', 'Otros'),
];

Future<void> launchExpenseImportFlow(BuildContext context) async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null || !context.mounted) {
    return;
  }

  final userDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .get();
  final familyId = userDoc.data()?['activeFamilyId'] as String?;
  if (!context.mounted) {
    return;
  }
  if ((familyId ?? '').isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Elegí un hogar activo antes de importar.')),
    );
    return;
  }

  final pick = await FilePicker.platform.pickFiles(
    withData: true,
    type: FileType.custom,
    allowedExtensions: const ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
  );
  final file = pick?.files.single;
  final bytes = file?.bytes;
  if (file == null || bytes == null || !context.mounted) {
    return;
  }

  _showProgress(context, 'Subiendo archivo...');
  try {
    final startCallable = craftrFunctions().httpsCallable('startExpenseImport');
    final contentType = _contentTypeForExtension(file.extension);
    final startRes = await startCallable.call<Map<String, dynamic>>({
      'familyId': familyId,
      'fileName': file.name,
      'mimeType': contentType,
    });
    final importJobId = (startRes.data['importJobId'] as String?) ?? '';
    final storagePath = (startRes.data['storagePath'] as String?) ?? '';
    if (importJobId.isEmpty || storagePath.isEmpty) {
      throw FirebaseFunctionsException(
        code: 'internal',
        message: 'No se pudo iniciar importación',
      );
    }

    final metadata = SettableMetadata(contentType: contentType);
    await FirebaseStorage.instance.ref(storagePath).putData(bytes, metadata);

    if (!context.mounted) {
      return;
    }
    _closeTopDialog(context);
    _showProgress(context, 'Procesando con IA...');
    final processCallable = craftrFunctions().httpsCallable(
      'processExpenseImport',
    );
    await processCallable.call<Map<String, dynamic>>({
      'familyId': familyId,
      'importJobId': importJobId,
    });

    if (!context.mounted) {
      return;
    }
    _closeTopDialog(context);
    await _openConfirmationEditor(
      context,
      familyId: familyId!,
      importJobId: importJobId,
    );
  } on FirebaseFunctionsException catch (error) {
    if (context.mounted) {
      _closeTopDialog(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message ?? 'Falló la importación')),
      );
    }
  } catch (_) {
    if (context.mounted) {
      _closeTopDialog(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo importar el archivo.')),
      );
    }
  }
}

Future<void> _openConfirmationEditor(
  BuildContext context, {
  required String familyId,
  required String importJobId,
}) async {
  final importDoc = await FirebaseFirestore.instance
      .collection('families')
      .doc(familyId)
      .collection('importJobs')
      .doc(importJobId)
      .get();
  final rawLines = (importDoc.data()?['proposedLines'] as List<dynamic>? ?? [])
      .cast<Map<String, dynamic>>();
  if (!context.mounted) {
    return;
  }
  if (rawLines.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('La IA no devolvió líneas para confirmar.')),
    );
    return;
  }

  final paymentMethodsSnap = await FirebaseFirestore.instance
      .collection('families')
      .doc(familyId)
      .collection('paymentMethods')
      .orderBy('name')
      .get();
  final paymentMethods = paymentMethodsSnap.docs
      .map((d) => {'id': d.id, 'name': (d.data()['name'] as String? ?? '—')})
      .toList();
  if (paymentMethods.isEmpty || !context.mounted) {
    return;
  }

  final editableLines = rawLines.map((line) {
    final paymentMethodId = (line['paymentMethodId'] as String?)?.trim();
    return <String, dynamic>{
      'amount': (line['amount'] as num?)?.toDouble() ?? 0,
      'categoryKey': (line['categoryKey'] as String?) ?? 'other',
      'occurredAtIso':
          (line['occurredAtIso'] as String?) ??
          DateTime.now().toIso8601String().substring(0, 10),
      'merchant': (line['merchant'] as String?) ?? '',
      'note': (line['note'] as String?) ?? '',
      'paymentMethodId': paymentMethodId?.isNotEmpty == true
          ? paymentMethodId
          : paymentMethods.first['id'],
    };
  }).toList();

  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: const Text('Confirmar importación'),
            content: SizedBox(
              width: 720,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Text(
                      'Revisá y editá las líneas antes de guardarlas en gastos.',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    for (var i = 0; i < editableLines.length; i++)
                      _ImportLineCard(
                        index: i,
                        line: editableLines[i],
                        paymentMethods: paymentMethods,
                        onChanged: () => setLocal(() {}),
                        onRemove: editableLines.length <= 1
                            ? null
                            : () => setLocal(() => editableLines.removeAt(i)),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Guardar gastos'),
              ),
            ],
          );
        },
      );
    },
  );

  if (confirmed != true || !context.mounted) {
    return;
  }

  _showProgress(context, 'Aplicando líneas...');
  try {
    final callable = craftrFunctions().httpsCallable('confirmExpenseImport');
    await callable.call<Map<String, dynamic>>({
      'familyId': familyId,
      'importJobId': importJobId,
      'lines': editableLines,
    });
    if (!context.mounted) {
      return;
    }
    Navigator.of(context, rootNavigator: true).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Importación aplicada (${editableLines.length} líneas).'),
      ),
    );
  } on FirebaseFunctionsException catch (error) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'No se pudo confirmar la importación'),
        ),
      );
    }
  }
}

void _showProgress(BuildContext context, String message) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    ),
  );
}

void _closeTopDialog(BuildContext context) {
  final navigator = Navigator.of(context, rootNavigator: true);
  if (navigator.canPop()) {
    navigator.pop();
  }
}

String _contentTypeForExtension(String? extension) {
  switch ((extension ?? '').toLowerCase()) {
    case 'pdf':
      return 'application/pdf';
    case 'png':
      return 'image/png';
    case 'webp':
      return 'image/webp';
    case 'jpg':
    case 'jpeg':
    default:
      return 'image/jpeg';
  }
}

class _ImportLineCard extends StatelessWidget {
  const _ImportLineCard({
    required this.index,
    required this.line,
    required this.paymentMethods,
    required this.onChanged,
    this.onRemove,
  });

  final int index;
  final Map<String, dynamic> line;
  final List<Map<String, String?>> paymentMethods;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'Línea ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (onRemove != null)
                  IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Eliminar línea',
                  ),
              ],
            ),
            TextFormField(
              initialValue: (line['amount'] as num).toStringAsFixed(2),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: 'Monto'),
              onChanged: (value) {
                line['amount'] =
                    double.tryParse(value.replaceAll(',', '.')) ?? 0;
                onChanged();
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: line['categoryKey'] as String? ?? 'other',
              decoration: const InputDecoration(labelText: 'Categoría'),
              items: _categoryChoices
                  .map(
                    (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                line['categoryKey'] = value ?? 'other';
                onChanged();
              },
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: line['paymentMethodId'] as String?,
              decoration: const InputDecoration(labelText: 'Método de pago'),
              items: paymentMethods
                  .map(
                    (pm) => DropdownMenuItem(
                      value: pm['id'],
                      child: Text(pm['name'] ?? '—'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                line['paymentMethodId'] = value ?? paymentMethods.first['id'];
                onChanged();
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: line['merchant'] as String? ?? '',
              decoration: const InputDecoration(labelText: 'Comercio'),
              onChanged: (value) {
                line['merchant'] = value.trim();
                onChanged();
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: line['note'] as String? ?? '',
              decoration: const InputDecoration(labelText: 'Nota'),
              onChanged: (value) {
                line['note'] = value.trim();
                onChanged();
              },
            ),
          ],
        ),
      ),
    );
  }
}
