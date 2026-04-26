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
  const FamilyAssistantPage({super.key, this.onClose});

  /// Si se muestra en un panel modal, se usa un botón cerrar en el app bar.
  final VoidCallback? onClose;

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
          return Scaffold(
            extendBodyBehindAppBar: onClose != null,
            appBar: onClose == null
                ? null
                : sanctuaryAppBar(
                    context,
                    title: 'Asistente',
                    leading: IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Cerrar',
                      onPressed: onClose,
                    ),
                  ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }
        final familyId = userSnap.data!.data()?['activeFamilyId'] as String?;
        if (familyId == null || familyId.isEmpty) {
          return Scaffold(
            extendBodyBehindAppBar: true,
            appBar: sanctuaryAppBar(
              context,
              title: 'Asistente',
              leading: onClose == null
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close),
                      tooltip: 'Cerrar',
                      onPressed: onClose,
                    ),
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
        return _FamilyAssistantBody(familyId: familyId, onClose: onClose);
      },
    );
  }
}

class _FamilyAssistantBody extends StatefulWidget {
  const _FamilyAssistantBody({required this.familyId, this.onClose});

  final String familyId;
  final VoidCallback? onClose;

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
  final List<_LocalUserMessage> _localMessages = <_LocalUserMessage>[];

  @override
  void initState() {
    super.initState();
    _refreshConnectivity();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
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
    final clientMessageId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final localMessage = _LocalUserMessage(
      clientMessageId: clientMessageId,
      text: text,
      createdAt: DateTime.now(),
      status: _LocalUserMessageStatus.pending,
    );
    setState(() {
      _controller.clear();
      _streamBuffer = null;
      _localMessages.add(localMessage);
    });
    await _sendLocalMessage(localMessage);
  }

  Future<void> _retryMessage(String clientMessageId) async {
    if (_sending) return;
    final index = _localMessages.indexWhere(
      (m) => m.clientMessageId == clientMessageId,
    );
    if (index < 0) return;
    final current = _localMessages[index];
    if (current.status != _LocalUserMessageStatus.failed) return;
    final retryMessage = current.copyWith(
      status: _LocalUserMessageStatus.pending,
      createdAt: DateTime.now(),
    );
    setState(() {
      _streamBuffer = null;
      _localMessages[index] = retryMessage;
    });
    await _sendLocalMessage(retryMessage);
  }

  Future<void> _sendLocalMessage(_LocalUserMessage localMessage) async {
    if (_online == false) {
      _markLocalMessageStatus(
        localMessage.clientMessageId,
        _LocalUserMessageStatus.failed,
      );
      return;
    }

    setState(() {
      _sending = true;
      _streamBuffer = null;
    });

    final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (idToken == null) {
      if (mounted) {
        _markLocalMessageStatus(
          localMessage.clientMessageId,
          _LocalUserMessageStatus.failed,
        );
        setState(() => _sending = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Sin sesión')));
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
      'message': localMessage.text,
      'clientMessageId': localMessage.clientMessageId,
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
      await for (final line
          in response.stream
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
          _markLocalMessageStatus(
            localMessage.clientMessageId,
            _LocalUserMessageStatus.sent,
          );
        } else if (t == 'delta') {
          final piece = map['text'] as String? ?? '';
          if (piece.isEmpty) {
            continue;
          }
          _markLocalMessageStatus(
            localMessage.clientMessageId,
            _LocalUserMessageStatus.sent,
          );
          streamAccum += piece;
          if (mounted) {
            setState(() => _streamBuffer = streamAccum);
          }
        } else if (t == 'error') {
          _markLocalMessageStatus(
            localMessage.clientMessageId,
            _LocalUserMessageStatus.failed,
          );
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
        _markLocalMessageStatus(
          localMessage.clientMessageId,
          _LocalUserMessageStatus.failed,
        );
        setState(() => _streamBuffer = null);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Sin conexión')));
      }
    } catch (e) {
      if (mounted) {
        _markLocalMessageStatus(
          localMessage.clientMessageId,
          _LocalUserMessageStatus.failed,
        );
        setState(() => _streamBuffer = null);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      client.close();
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  void _markLocalMessageStatus(
    String clientMessageId,
    _LocalUserMessageStatus status,
  ) {
    if (!mounted) return;
    final index = _localMessages.indexWhere(
      (m) => m.clientMessageId == clientMessageId,
    );
    if (index < 0) return;
    final current = _localMessages[index];
    if (current.status == status) return;
    setState(() {
      _localMessages[index] = current.copyWith(status: status);
    });
  }

  void _openThread(String? threadId) {
    setState(() {
      _activeThreadId = threadId;
      _streamBuffer = null;
    });
    _scaffoldKey.currentState?.closeEndDrawer();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final topPad = MediaQuery.paddingOf(context).top + kToolbarHeight + 8;
    final offline = _online == false;
    final threadId = _activeThreadId;
    final hasLocalMessages = _localMessages.isNotEmpty;

    return Scaffold(
      key: _scaffoldKey,
      extendBodyBehindAppBar: true,
      appBar: sanctuaryAppBar(
        context,
        title: 'Asistente',
        leading: widget.onClose == null
            ? null
            : IconButton(
                icon: const Icon(Icons.close),
                tooltip: 'Cerrar',
                onPressed: widget.onClose,
              ),
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
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
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
                if (threadId == null && !hasLocalMessages)
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
                    localMessages: _localMessages,
                    onRetry: _retryMessage,
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
                    onPressed: offline || _sending ? null : _send,
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
    this.threadId,
    this.streamingReply,
    this.sending = false,
    this.localMessages = const <_LocalUserMessage>[],
    required this.onRetry,
  });

  final String familyId;
  final String? threadId;
  final String? streamingReply;
  final bool sending;
  final List<_LocalUserMessage> localMessages;
  final ValueChanged<String> onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final canLoadRemote = threadId != null && threadId!.isNotEmpty;
    final query = canLoadRemote
        ? FirebaseFirestore.instance
              .collection('families')
              .doc(familyId)
              .collection('assistantThreads')
              .doc(threadId!)
              .collection('messages')
              .orderBy('createdAt', descending: false)
        : null;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query?.snapshots(includeMetadataChanges: true),
      builder: (context, snap) {
        if (canLoadRemote && !snap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        final docs =
            snap.data?.docs ??
            const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
        final serverClientMessageIds = docs
            .map((d) => d.data()['clientMessageId'] as String?)
            .whereType<String>()
            .toSet();
        final visibleLocalMessages = localMessages.where((m) {
          if (m.status == _LocalUserMessageStatus.failed) return true;
          return !serverClientMessageIds.contains(m.clientMessageId);
        }).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        final hasStreamPreview =
            streamingReply != null && streamingReply!.isNotEmpty;
        if (docs.isEmpty &&
            visibleLocalMessages.isEmpty &&
            !hasStreamPreview &&
            !sending) {
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
                alignment: isUser
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
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
            ...visibleLocalMessages.map((m) {
              return Align(
                alignment: Alignment.centerRight,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.sizeOf(context).width * 0.82,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(18),
                      topRight: Radius.circular(18),
                      bottomLeft: Radius.circular(18),
                      bottomRight: Radius.circular(4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        m.text,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (m.status == _LocalUserMessageStatus.failed)
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 6,
                          children: [
                            Text(
                              'No enviado',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: scheme.error,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            TextButton(
                              onPressed: () => onRetry(m.clientMessageId),
                              child: const Text('Reintentar'),
                            ),
                          ],
                        )
                      else
                        Text(
                          m.status == _LocalUserMessageStatus.pending
                              ? 'Enviando...'
                              : 'Enviado',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: scheme.onPrimaryContainer.withValues(
                                  alpha: 0.78,
                                ),
                              ),
                        ),
                    ],
                  ),
                ),
              );
            }),
            if (sending && !hasStreamPreview)
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'IA escribiendo...',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              )
            else if (hasStreamPreview)
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
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

enum _LocalUserMessageStatus { pending, sent, failed }

class _LocalUserMessage {
  const _LocalUserMessage({
    required this.clientMessageId,
    required this.text,
    required this.createdAt,
    required this.status,
  });

  final String clientMessageId;
  final String text;
  final DateTime createdAt;
  final _LocalUserMessageStatus status;

  _LocalUserMessage copyWith({
    DateTime? createdAt,
    _LocalUserMessageStatus? status,
  }) {
    return _LocalUserMessage(
      clientMessageId: clientMessageId,
      text: text,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
    );
  }
}
