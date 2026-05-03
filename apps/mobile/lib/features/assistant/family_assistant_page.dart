import 'dart:async';
import 'dart:io' show SocketException;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:craftr_mobile/design_system/design_system.dart';
import 'package:craftr_mobile/features/assistant/assistant_chat_local_visibility.dart';
import 'package:craftr_mobile/features/assistant/assistant_functions_client.dart';
import 'package:craftr_mobile/features/assistant/assistant_message_buffer.dart';
import 'package:craftr_mobile/features/assistant/active_conversation_state.dart';
import 'package:craftr_mobile/features/assistant/widgets/assistant_markdown_message.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
                    leading: Semantics(
                      button: true,
                      label: 'Cerrar asistente',
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Cerrar',
                        onPressed: onClose,
                      ),
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
                  : Semantics(
                      button: true,
                      label: 'Cerrar asistente',
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Cerrar',
                        onPressed: onClose,
                      ),
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
  final _chatScrollController = ScrollController();
  final _activeConversationResolver = ActiveConversationResolver(
    localStore: SecureLocalActiveConversationStore(),
    remoteStore: FirestoreRemoteActiveConversationStore(),
    threadsStore: FirestoreAssistantConversationThreadsStore(),
  );
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  final _assistantFunctionsClient = AssistantFunctionsClient();
  late final AssistantMessageBuffer _messageBuffer;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _threadsSub;
  String? _activeThreadId;
  String? _uid;
  bool _sending = false;
  bool _bootstrappingConversation = true;
  bool? _online;
  String? _streamBuffer;
  bool _scrollScheduled = false;
  final List<_LocalUserMessage> _localMessages = <_LocalUserMessage>[];

  @override
  void initState() {
    super.initState();
    _messageBuffer = AssistantMessageBuffer(onFlush: _sendBufferedBatch);
    _uid = FirebaseAuth.instance.currentUser?.uid;
    _refreshConnectivity();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (!mounted) return;
      setState(() => _online = _hasConnectivity(results));
    });
    _subscribeToThreads();
    _bootstrapActiveConversation();
  }

  @override
  void didUpdateWidget(covariant _FamilyAssistantBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.familyId != widget.familyId) {
      _subscribeToThreads();
      _bootstrapActiveConversation();
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _assistantFunctionsClient.dispose();
    _messageBuffer.dispose();
    _threadsSub?.cancel();
    _chatScrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animated = true}) {
    if (_scrollScheduled) return;
    _scrollScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollScheduled = false;
      if (!mounted || !_chatScrollController.hasClients) return;
      final target = _chatScrollController.position.maxScrollExtent;
      if (animated) {
        _chatScrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      } else {
        _chatScrollController.jumpTo(target);
      }
    });
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

  Future<void> _bootstrapActiveConversation() async {
    final uid = _uid;
    if (uid == null) {
      if (mounted) {
        setState(() => _bootstrappingConversation = false);
      }
      return;
    }
    setState(() => _bootstrappingConversation = true);
    try {
      final resolved = await _activeConversationResolver.bootstrap(
        uid: uid,
        familyId: widget.familyId,
      );
      if (!mounted) return;
      setState(() {
        _activeThreadId = resolved;
        _bootstrappingConversation = false;
      });
      _scrollToBottom(animated: false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _bootstrappingConversation = false);
    }
  }

  void _subscribeToThreads() {
    _threadsSub?.cancel();
    _threadsSub = FirebaseFirestore.instance
        .collection('families')
        .doc(widget.familyId)
        .collection('assistantThreads')
        .orderBy('updatedAt', descending: true)
        .snapshots(includeMetadataChanges: true)
        .listen((snap) => _reconcileActiveThread(snap.docs));
  }

  Future<void> _reconcileActiveThread(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final uid = _uid;
    if (!mounted || uid == null) return;
    if (docs.isEmpty) {
      if (_activeThreadId != null) {
        await _activeConversationResolver.setActiveConversation(
          uid: uid,
          familyId: widget.familyId,
          conversationId: null,
        );
        if (mounted) {
          setState(() => _activeThreadId = null);
        }
      }
      return;
    }

    final current = _activeThreadId;
    if (current != null && docs.any((d) => d.id == current)) {
      return;
    }

    final fallback = await _activeConversationResolver.ensureStillValid(
      uid: uid,
      familyId: widget.familyId,
      currentConversationId: current,
    );
    if (!mounted) return;
    setState(() => _activeThreadId = fallback);
  }

  Future<void> _startNewConversation() async {
    final uid = _uid;
    if (uid == null || _sending) return;
    try {
      await _activeConversationResolver.setActiveConversation(
        uid: uid,
        familyId: widget.familyId,
        conversationId: null,
      );
      if (!mounted) return;
      setState(() {
        _activeThreadId = null;
        _streamBuffer = null;
      });
      _scrollToBottom(animated: false);
      _scaffoldKey.currentState?.closeEndDrawer();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('No se pudo iniciar chat: $e')));
    }
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
    _scrollToBottom();
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
      _streamBuffer = null;
    });
    _controller.clear();
    _messageBuffer.queue(
      localMessage.text,
      clientMessageId: localMessage.clientMessageId,
    );
  }

  Future<void> _sendBufferedBatch(BufferedAssistantBatch batch) async {
    final bufferedMessageIds = _localMessages
        .where((m) => m.status == _LocalUserMessageStatus.pending)
        .map((m) => m.clientMessageId)
        .toList(growable: false);
    if (!mounted) return;
    setState(() {
      _sending = true;
      _streamBuffer = null;
    });
    final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (idToken == null) {
      if (mounted) {
        _markLocalMessageStatuses(
          bufferedMessageIds,
          _LocalUserMessageStatus.failed,
        );
        setState(() => _sending = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Sin sesión')));
      }
      return;
    }

    var streamAccum = '';
    try {
      await for (final map in _assistantFunctionsClient.streamAssistantChat(
        idToken: idToken,
        familyId: widget.familyId,
        threadId: _activeThreadId,
        message: batch.message,
        clientMessageIds: batch.clientMessageIds,
        bufferSize: batch.bufferSize,
        delayMs: batch.delayMs,
        tokensSavedEstimated: batch.tokensSavedEstimated,
      )) {
        final t = map['type'] as String?;
        if (t == 'meta') {
          final threadId = map['threadId'] as String?;
          if (threadId != null && threadId.isNotEmpty && mounted) {
            setState(() => _activeThreadId = threadId);
            _scrollToBottom(animated: false);
          }
          _markLocalMessageStatuses(
            bufferedMessageIds,
            _LocalUserMessageStatus.sent,
          );
        } else if (t == 'delta') {
          final piece = map['text'] as String? ?? '';
          if (piece.isEmpty) {
            continue;
          }
          _markLocalMessageStatuses(
            bufferedMessageIds,
            _LocalUserMessageStatus.sent,
          );
          streamAccum += piece;
          if (mounted) {
            setState(() => _streamBuffer = streamAccum);
            _scrollToBottom(animated: false);
          }
        } else if (t == 'error') {
          _markLocalMessageStatuses(
            bufferedMessageIds,
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
            _scrollToBottom(animated: false);
          }
          return;
        }
      }
    } on SocketException {
      if (mounted) {
        _markLocalMessageStatuses(
          bufferedMessageIds,
          _LocalUserMessageStatus.failed,
        );
        setState(() => _streamBuffer = null);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Sin conexión')));
      }
    } catch (e) {
      if (mounted) {
        _markLocalMessageStatuses(
          bufferedMessageIds,
          _LocalUserMessageStatus.failed,
        );
        setState(() => _streamBuffer = null);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
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

  void _markLocalMessageStatuses(
    List<String> clientMessageIds,
    _LocalUserMessageStatus status,
  ) {
    for (final clientMessageId in clientMessageIds) {
      _markLocalMessageStatus(clientMessageId, status);
    }
  }

  Future<void> _openThread(String threadId) async {
    final uid = _uid;
    if (uid == null) return;
    await _activeConversationResolver.setActiveConversation(
      uid: uid,
      familyId: widget.familyId,
      conversationId: threadId,
    );
    if (!mounted) return;
    setState(() {
      _activeThreadId = threadId;
      _streamBuffer = null;
    });
    _scrollToBottom(animated: false);
    _scaffoldKey.currentState?.closeEndDrawer();
  }

  String _formatHistoryFallbackDate(dynamic rawTimestamp) {
    if (rawTimestamp is! Timestamp) {
      return 'Conversación';
    }
    final date = rawTimestamp.toDate();
    final dd = date.day.toString().padLeft(2, '0');
    final mm = date.month.toString().padLeft(2, '0');
    final yyyy = date.year.toString();
    final hh = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '$dd/$mm/$yyyy $hh:$min';
  }

  String _threadTitle(Map<String, dynamic> data) {
    final conversationTitle = (data['conversationTitle'] as String?)?.trim();
    if (conversationTitle != null && conversationTitle.isNotEmpty) {
      return conversationTitle;
    }
    return _formatHistoryFallbackDate(data['createdAt'] ?? data['updatedAt']);
  }

  Future<void> _renameThreadTitle({
    required String threadId,
    required String currentTitle,
  }) async {
    final controller = TextEditingController(text: currentTitle);
    final newTitle = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Renombrar conversación'),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 1,
            maxLines: 2,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: 'Ej: Plan semanal de comidas',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (!mounted || newTitle == null || newTitle.isEmpty) {
      return;
    }

    try {
      await _assistantFunctionsClient.renameAssistantThreadTitle(
        familyId: widget.familyId,
        threadId: threadId,
        conversationTitle: newTitle,
      );
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'No se pudo renombrar la conversación'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo renombrar la conversación')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final topPad = MediaQuery.paddingOf(context).top + kSanctuaryAppBarToolbarHeight + 8;
    final offline = _online == false;
    final threadId = _activeThreadId;

    return Scaffold(
      key: _scaffoldKey,
      extendBodyBehindAppBar: true,
      appBar: sanctuaryAppBar(
        context,
        title: 'Asistente',
        leading: widget.onClose == null
            ? null
            : Semantics(
                button: true,
                label: 'Cerrar asistente',
                child: IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Cerrar',
                  onPressed: widget.onClose,
                ),
              ),
        actions: [
          Semantics(
            button: true,
            label: 'Abrir historial de conversaciones',
            child: IconButton(
              tooltip: 'Conversaciones',
              icon: const Icon(Icons.history),
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            ),
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
                title: const Text('Nuevo chat'),
                onTap: _startNewConversation,
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
                        final data = d.data();
                        final title = _threadTitle(data);
                        final selected = d.id == _activeThreadId;
                        return ListTile(
                          title: Text(
                            title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit_outlined),
                            tooltip: 'Renombrar',
                            onPressed: () => _renameThreadTitle(
                              threadId: d.id,
                              currentTitle: title,
                            ),
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
              controller: _chatScrollController,
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
                if (_bootstrappingConversation)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (threadId == null)
                  Text(
                    'Abrí "Historial" y tocá "Nuevo chat" para iniciar una conversación.',
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
                    onContentChanged: () => _scrollToBottom(animated: false),
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
                  Semantics(
                    button: true,
                    enabled: !offline && !_sending,
                    label: _sending
                        ? 'Enviando mensaje'
                        : 'Enviar mensaje al asistente',
                    child: Tooltip(
                      message: _sending ? 'Enviando mensaje' : 'Enviar mensaje',
                      child: FilledButton(
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
                    ),
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
    this.onContentChanged,
  });

  final String familyId;
  final String? threadId;
  final String? streamingReply;
  final bool sending;
  final List<_LocalUserMessage> localMessages;
  final ValueChanged<String> onRetry;
  final VoidCallback? onContentChanged;

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
        final serverClientMessageIds = serverStoredClientMessageIds(
          docs.map((d) => d.data()),
        );
        final visibleLocalMessages = localMessages.where((m) {
          return shouldShowLocalUserBubble(
            isFailed: m.status == _LocalUserMessageStatus.failed,
            isSent: m.status == _LocalUserMessageStatus.sent,
            clientMessageId: m.clientMessageId,
            serverClientIds: serverClientMessageIds,
          );
        }).toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        final hasStreamPreview =
            streamingReply != null && streamingReply!.isNotEmpty;
        if (docs.isEmpty &&
            visibleLocalMessages.isEmpty &&
            !hasStreamPreview &&
            !sending) {
          return const SizedBox.shrink();
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          onContentChanged?.call();
        });
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
                  child: isUser
                      ? Text(
                          text,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: scheme.onPrimaryContainer),
                        )
                      : AssistantMarkdownMessage(
                          text: text,
                          textColor: scheme.onSurface,
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
                              ?.copyWith(color: scheme.onPrimaryContainer),
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
                            ?.copyWith(color: scheme.onSurface),
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
                  child: AssistantMarkdownMessage(
                    text: streamingReply!,
                    textColor: scheme.onSurface,
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
