import 'dart:async';

typedef DateTimeNow = DateTime Function();

class BufferedAssistantBatch {
  const BufferedAssistantBatch({
    required this.message,
    required this.clientMessageIds,
    required this.bufferSize,
    required this.delayMs,
    required this.tokensSavedEstimated,
  });

  final String message;
  final List<String> clientMessageIds;
  final int bufferSize;
  final int delayMs;
  final int tokensSavedEstimated;
}

class AssistantMessageBuffer {
  AssistantMessageBuffer({
    required this.onFlush,
    this.window = const Duration(milliseconds: 1200),
    this.separator = '\n\n',
    this.tokensPerCallOverheadEstimate = 120,
    DateTimeNow? now,
  }) : _now = now ?? DateTime.now;

  final Duration window;
  final String separator;
  final int tokensPerCallOverheadEstimate;
  final Future<void> Function(BufferedAssistantBatch batch) onFlush;
  final DateTimeNow _now;

  final List<_PendingMessage> _pending = <_PendingMessage>[];
  Timer? _flushTimer;
  DateTime? _windowStartedAt;
  bool _flushInProgress = false;

  bool get hasPending => _pending.isNotEmpty;

  void queue(String rawText, {required String clientMessageId}) {
    final text = rawText.trim();
    if (text.isEmpty) return;

    final now = _now();
    final startsNewWindow = _pending.isEmpty;
    _windowStartedAt ??= now;
    _pending.add(
      _PendingMessage(
        text: text,
        clientMessageId: clientMessageId,
        queuedAt: now,
      ),
    );

    if (startsNewWindow) {
      _flushTimer?.cancel();
      _flushTimer = Timer(window, _flush);
    }
  }

  Future<void> flushNow() async {
    _flushTimer?.cancel();
    await _flush();
  }

  Future<void> _flush() async {
    if (_flushInProgress || _pending.isEmpty) {
      return;
    }
    _flushInProgress = true;
    final flushedAt = _now();
    final startedAt = _windowStartedAt ?? _pending.first.queuedAt;
    final batchSize = _pending.length;
    final mergedMessage = _pending.map((m) => m.text).join(separator);
    final clientMessageIds = _pending.map((m) => m.clientMessageId).toList();
    _pending.clear();
    _windowStartedAt = null;
    try {
      await onFlush(
        BufferedAssistantBatch(
          message: mergedMessage,
          clientMessageIds: clientMessageIds,
          bufferSize: batchSize,
          delayMs: flushedAt.difference(startedAt).inMilliseconds,
          tokensSavedEstimated: batchSize <= 1
              ? 0
              : (batchSize - 1) * tokensPerCallOverheadEstimate,
        ),
      );
    } finally {
      _flushInProgress = false;
      if (_pending.isNotEmpty) {
        _flushTimer?.cancel();
        _flushTimer = Timer(window, _flush);
      }
    }
  }

  void dispose() {
    _flushTimer?.cancel();
    _flushTimer = null;
    _pending.clear();
    _windowStartedAt = null;
  }
}

class _PendingMessage {
  const _PendingMessage({
    required this.text,
    required this.clientMessageId,
    required this.queuedAt,
  });

  final String text;
  final String clientMessageId;
  final DateTime queuedAt;
}
