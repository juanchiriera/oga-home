import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:craftr_mobile/design_system/design_system.dart';
import 'package:craftr_mobile/services/functions_region.dart';
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Chat del asistente por familia: historial en Firestore, turnos vía callable
/// [familyAssistantChat]. Requiere red (banner claro si no hay conectividad).
class FamilyAssistantPage extends StatelessWidget {
  const FamilyAssistantPage({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Sin sesión')));
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(includeMetadataChanges: true),
      builder: (context, userSnap) {
        if (!userSnap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final familyId = userSnap.data!.data()?['activeFamilyId'] as String?;
        if (familyId == null || familyId.isEmpty) {
          return Scaffold(
            extendBodyBehindAppBar: true,
            appBar: sanctuaryAppBar(
              context,
              title: 'Asistente',
            ),
            body: Center(
              child: Padding(
                padding: kSanctuaryScreenPadding,
                child: Text(
                  'Creá o elegí un hogar para usar el asistente.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
          );
        }
        return _FamilyAssistantBody(familyId: familyId);
      },
    );
  }
}

class _FamilyAssistantBody extends StatefulWidget {
  const _FamilyAssistantBody({required this.familyId});

  final String familyId;

  @override
  State<_FamilyAssistantBody> createState() => _FamilyAssistantBodyState();
}

class _FamilyAssistantBodyState extends State<_FamilyAssistantBody> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _controller = TextEditingController();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  String? _activeThreadId;
  bool _sending = false;
  bool? _online;

  @override
  void initState() {
    super.initState();
    _refreshConnectivity();
    _connectivitySub =
        Connectivity().onConnectivityChanged.listen((results) {
      if (!mounted) return;
      setState(() => _online = _hasConnectivity(results));
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _refreshConnectivity() async {
    final r = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() => _online = _hasConnectivity(r));
    }
  }

  bool _hasConnectivity(List<ConnectivityResult> results) {
    return results.any((e) => e != ConnectivityResult.none);
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    if (_online == false) return;

    setState(() => _sending = true);
    try {
      final data = <String, dynamic>{
        'familyId': widget.familyId,
        'message': text,
      };
      final tid = _activeThreadId;
      if (tid != null && tid.isNotEmpty) {
        data['threadId'] = tid;
      }

      final result = await craftrFunctions()
          .httpsCallable('familyAssistantChat')
          .call(data);

      final map = Map<String, dynamic>.from(result.data as Map);
      final threadId = map['threadId'] as String?;
      if (threadId != null && threadId.isNotEmpty && mounted) {
        setState(() => _activeThreadId = threadId);
      }
      if (mounted) {
        _controller.clear();
      }
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? 'No se pudo enviar el mensaje')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  void _openThread(String? threadId) {
    setState(() => _activeThreadId = threadId);
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final topPad = MediaQuery.paddingOf(context).top + kToolbarHeight + 8;
    final offline = _online == false;
    final threadId = _activeThreadId;

    return Scaffold(
      key: _scaffoldKey,
      extendBodyBehindAppBar: true,
      appBar: sanctuaryAppBar(
        context,
        title: 'Asistente',
        actions: [
          IconButton(
            tooltip: 'Conversaciones',
            icon: const Icon(Icons.history),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
      endDrawer: Drawer(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Historial',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.add_comment_outlined),
                title: const Text('Nueva conversación'),
                onTap: () => _openThread(null),
              ),
              const Divider(height: 1),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('families')
                      .doc(widget.familyId)
                      .collection('assistantThreads')
                      .orderBy('updatedAt', descending: true)
                      .snapshots(includeMetadataChanges: true),
                  builder: (context, snap) {
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snap.data!.docs;
                    if (docs.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Todavía no hay conversaciones. Mandá un mensaje para crear la primera.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, i) {
                        final d = docs[i];
                        final title =
                            d.data()['title'] as String? ?? 'Conversación';
                        final selected = d.id == _activeThreadId;
                        return ListTile(
                          title: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          selected: selected,
                          onTap: () => _openThread(d.id),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          if (offline)
            MaterialBanner(
              content: const Text(
                'Sin conexión: el asistente necesita internet para responder.',
              ),
              leading: Icon(Icons.wifi_off, color: scheme.error),
              backgroundColor: scheme.errorContainer,
              actions: [
                TextButton(
                  onPressed: _refreshConnectivity,
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                24,
                topPad + (offline ? 8 : 0),
                24,
                16,
              ),
              children: [
                SanctuaryAssistantHero(
                  greetingLine: '¿En qué te ayudo?',
                  subtitle:
                      'Preguntá por gastos, despensa, recetas o ideas para el hogar.',
                ),
                const SizedBox(height: 20),
                if (threadId == null)
                  Text(
                    'Escribí abajo para empezar una conversación nueva.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  )
                else
                  _MessagesList(
                    familyId: widget.familyId,
                    threadId: threadId,
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 5,
                      enabled: !offline && !_sending,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: offline
                            ? 'Sin conexión'
                            : 'Escribí tu mensaje…',
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed:
                        offline || _sending ? null : _send,
                    style: FilledButton.styleFrom(
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(14),
                    ),
                    child: _sending
                        ? SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.onPrimary,
                            ),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessagesList extends StatelessWidget {
  const _MessagesList({
    required this.familyId,
    required this.threadId,
  });

  final String familyId;
  final String threadId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final query = FirebaseFirestore.instance
        .collection('families')
        .doc(familyId)
        .collection('assistantThreads')
        .doc(threadId)
        .collection('messages')
        .orderBy('createdAt', descending: false);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(includeMetadataChanges: true),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final docs = snap.data!.docs;
        if (docs.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          children: docs.map((d) {
            final data = d.data();
            final role = data['role'] as String? ?? '';
            final text = data['text'] as String? ?? '';
            final isUser = role == 'user';
            return Align(
              alignment:
                  isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.82,
                ),
                decoration: BoxDecoration(
                  color: isUser
                      ? scheme.primaryContainer
                      : scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isUser ? 18 : 4),
                    bottomRight: Radius.circular(isUser ? 4 : 18),
                  ),
                ),
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isUser
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}
