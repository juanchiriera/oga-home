import 'package:craftr_mobile/design_system/design_system.dart';
import 'package:craftr_mobile/services/functions_region.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CreateFamilyPage extends StatefulWidget {
  const CreateFamilyPage({super.key});

  @override
  State<CreateFamilyPage> createState() => _CreateFamilyPageState();
}

class _CreateFamilyPageState extends State<CreateFamilyPage> {
  final _name = TextEditingController(text: 'Mi hogar');
  String _currency = 'ARS';
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final callable = craftrFunctions().httpsCallable('createFamily');
      await callable.call<Map<String, dynamic>>({
        'name': _name.text.trim(),
        'baseCurrency': _currency,
      });
      if (mounted) {
        context.go('/app');
      }
    } on FirebaseFunctionsException catch (e) {
      setState(() => _error = e.message ?? e.code);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: sanctuaryAppBar(context, title: 'Crear hogar'),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          24,
          MediaQuery.paddingOf(context).top + kToolbarHeight + 8,
          24,
          32 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          CozyCard(
            child: Text(
              'Completá los datos para crear tu espacio familiar compartido.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Nombre del hogar'),
          ),
          const SizedBox(height: 16),
          InputDecorator(
            decoration: const InputDecoration(labelText: 'Moneda base'),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _currency,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(value: 'ARS', child: Text('ARS')),
                  DropdownMenuItem(value: 'USD', child: Text('USD')),
                  DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                ],
                onChanged: _busy
                    ? null
                    : (v) => setState(() => _currency = v ?? 'ARS'),
              ),
            ),
          ),
          const SizedBox(height: 24),
          CozyPrimaryButton(
            onPressed: _busy ? null : _submit,
            label: _busy ? 'Creando…' : 'Crear hogar',
            icon: Icons.home_work_rounded,
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }
}
