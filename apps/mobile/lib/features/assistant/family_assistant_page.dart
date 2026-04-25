import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:craftr_mobile/design_system/design_system.dart';
import 'package:craftr_mobile/services/functions_region.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Chat del asistente por familia: historial en Firestore, turnos vía
/// [familyAssistantChatStream] (NDJSON, chunks de texto; requiere red).
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
  String? _streamBuffer;

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

    setState(() {
      _sending = true;
      _streamBuffer = null;
    });
    _controller.clear();

    final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (idToken == null) {
      if (mounted) {
        setState(() => _sending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sin sesión')),
        );
      }
      return;
    }

    final uri = Uri.parse(familyAssistantStreamUrl());
    final request = http.Request('POST', uri);
    request.headers['Authorization'] = 'Bearer $idToken';
    request.headers['Content-Type'] = 'application/json; charset=utf-8';
    request.body = jsonEncode({
      'familyId': widget.familyId,
      if (_activeThreadId != null && _activeThreadId!.isNotEmpty)
        'threadId': _activeThreadId!,
      'message': text,
    });

    final client = http.Client();
    var streamAccum = '';
    try {
      final response = await client.send(request);
      if (response.statusCode != 200) {
        final buf = StringBuffer();
        await for (final s in response.stream.transform(utf8.decoder)) {
          buf.write(s);
        }
        throw Exception('HTTP ${response.statusCode}: ${buf.toString()}');
      }
      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (line.isEmpty) {
          continue;
        }
        final map = jsonDecode(line) as Map<String, dynamic>;
        final t = map['type'] as String?;
        if (t == 'meta') {
          final threadId = map['threadId'] as String?;
          if (threadId != null && threadId.isNotEmpty && mounted) {
            setState(() => _activeThreadId = threadId);
          }
        } else if (t == 'delta') {
          final piece = map['text'] as String? ?? '';
          if (piece.isEmpty) {
            continue;
          }
          streamAccum += piece;
          if (mounted) {
            setState(() => _streamBuffer = streamAccum);
          }
        } else if (t == 'error') {
          final m = map['message'] as String? ?? 'Error del asistente';
          if (mounted) {
            setState(() => _streamBuffer = null);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(m)));
          }
          return;
        } else if (t == 'done') {
          if (mounted) {
            setState(() => _streamBuffer = null);
          }
          return;
        }
      }
    } on SocketException {
      if (mounted) {
        setState(() => _streamBuffer = null);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sin conexión')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _streamBuffer = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      client.close();
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  void _openThread(String? threadId) {
    setState(() {
      _activeThreadId = threadId;
      _streamBuffer = null;
    });
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
                    streamingReply: _streamBuffer,
                    sending: _sending,
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
    this.streamingReply,
    this.sending = false,
  });

  final String familyId;
  final String threadId;
  final String? streamingReply;
  final bool sending;

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
        final hasStreamPreview =
            streamingReply != null && streamingReply!.isNotEmpty;
        if (docs.isEmpty && !hasStreamPreview && !sending) {
          return const SizedBox.shrink();
        }
        return Column(
          children: [
            ...docs.map((d) {
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
            }),
            if (sending && !hasStreamPreview)
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  child: const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (hasStreamPreview)
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * 0.82,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(4),
                      bottomRight: Radius.circular(18),
                    ),
                  ),
                  child: Text(
                    streamingReply!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
