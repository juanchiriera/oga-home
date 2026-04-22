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
    return Scaffold(
      appBar: AppBar(title: const Text('Invitación')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Token: ${widget.token.isEmpty ? "—" : "${widget.token.substring(0, widget.token.length > 8 ? 8 : widget.token.length)}…"}',
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: (_busy || widget.token.isEmpty) ? null : _accept,
              child: Text(_busy ? 'Procesando…' : 'Unirme al hogar'),
            ),
            if (_message != null) ...[
              const SizedBox(height: 16),
              Text(_message!),
            ],
          ],
        ),
      ),
    );
  }
}
