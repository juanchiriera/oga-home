/// Dedupe optimistic user bubbles against persisted Firestore assistant messages.
Set<String> serverStoredClientMessageIds(
  Iterable<Map<String, dynamic>> messageDocsData,
) {
  final out = <String>{};
  for (final data in messageDocsData) {
    final single = data['clientMessageId'] as String?;
    if (single != null && single.trim().isNotEmpty) {
      out.add(single.trim());
    }
    final multi = data['clientMessageIds'];
    if (multi is List) {
      for (final e in multi) {
        if (e is String && e.trim().isNotEmpty) {
          out.add(e.trim());
        }
      }
    }
  }
  return out;
}

/// Whether a local optimistic row should still render under [serverClientIds].
///
/// - Failed: always show (retry UI).
/// - Sent: never show (server row is source of truth; backend may omit ids briefly).
/// - Pending: show unless Firestore already echoed this [clientMessageId].
bool shouldShowLocalUserBubble({
  required bool isFailed,
  required bool isSent,
  required String clientMessageId,
  required Set<String> serverClientIds,
}) {
  if (isFailed) return true;
  if (isSent) return false;
  return !serverClientIds.contains(clientMessageId);
}
