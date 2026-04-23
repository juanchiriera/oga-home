import 'package:craftr_mobile/design_system/design_system.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:craftr_mobile/services/functions_region.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class InviteAcceptPage extends StatefulWidget {
  const InviteAcceptPage({super.key, required this.token});

  final String token;

  @override
  State<InviteAcceptPage> createState() => _InviteAcceptPageState();
}

class _InviteAcceptPageState extends State<InviteAcceptPage> {
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    if (widget.token.isEmpty) {
      _message = 'Token inválido';
    }
  }

  Future<void> _accept() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final callable = craftrFunctions().httpsCallable('acceptFamilyInvite');
      await callable.call<Map<String, dynamic>>({'token': widget.token});
      if (mounted) {
        context.go('/app');
      }
    } on FirebaseFunctionsException catch (e) {
      setState(() => _message = e.message ?? e.code);
    } catch (e) {
      setState(() => _message = e.toString());
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
    final shortToken = widget.token.isEmpty
        ? '—'
        : '${widget.token.substring(0, widget.token.length > 8 ? 8 : widget.token.length)}…';
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: sanctuaryAppBar(context, title: 'Invitación'),
      body: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          MediaQuery.paddingOf(context).top + kToolbarHeight + 8,
          24,
          24 + MediaQuery.paddingOf(context).bottom,
        ),
        child: ListView(
          children: [
            CozyCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unite al hogar',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: scheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Código de invitación: $shortToken',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            CozyPrimaryButton(
              onPressed: (_busy || widget.token.isEmpty) ? null : _accept,
              label: _busy ? 'Procesando…' : 'Unirme al hogar',
              icon: Icons.group_add_rounded,
            ),
            if (_message != null) ...[
              const SizedBox(height: 16),
              Text(
                _message!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.error,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
