import 'package:cloud_functions/cloud_functions.dart';
import 'package:oga/l10n/l10n.dart';
import 'package:oga/services/functions_region.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

/// Llama a `createFamilyInvite` y muestra un bottom sheet para copiar/compartir el enlace.
Future<void> createAndShowFamilyInviteLink(
  BuildContext context,
  String familyId,
) async {
  final l10n = context.l10n;
  final messenger = ScaffoldMessenger.maybeOf(context);

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return PopScope(
        canPop: false,
        child: Dialog(
          backgroundColor: Theme.of(dialogContext).colorScheme.surface,
          child: const Padding(
            padding: EdgeInsets.all(28),
            child: SizedBox(
              width: 48,
              height: 48,
              child: CircularProgressIndicator(strokeWidth: 3),
            ),
          ),
        ),
      );
    },
  );

  try {
    final callable = craftrFunctions().httpsCallable('createFamilyInvite');
    final result = await callable.call({'familyId': familyId});
    final raw = result.data;
    if (raw is! Map) {
      throw StateError('Respuesta inválida del servidor');
    }
    final map = Map<Object?, Object?>.from(raw);
    final deepLink = map['deepLink'] as String?;
    if (deepLink == null || deepLink.isEmpty) {
      throw StateError('Sin enlace en la respuesta');
    }
    final expiresMs = (map['expiresAt'] as num?)?.toInt();

    if (!context.mounted) return;
    Navigator.of(context, rootNavigator: true).pop();

    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final scheme = theme.colorScheme;
        final expiresLine = expiresMs != null
            ? l10n.inviteCreatedExpires(
                _formatInviteExpiry(sheetContext, expiresMs),
              )
            : null;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.inviteCreatedSheetTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.inviteCreatedSheetSubtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                if (expiresLine != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    expiresLine,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: SelectableText(
                      deepLink,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: deepLink));
                          if (sheetContext.mounted) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              SnackBar(content: Text(l10n.inviteCopiedToClipboard)),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy_rounded, size: 20),
                        label: Text(l10n.inviteLinkCopy),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () async {
                          await Share.share(
                            deepLink,
                            subject: l10n.inviteCreatedSheetTitle,
                          );
                        },
                        icon: const Icon(Icons.share_rounded, size: 20),
                        label: Text(l10n.inviteLinkShare),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  } on FirebaseFunctionsException catch (e) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    final msg = e.code == 'permission-denied'
        ? l10n.inviteCreateErrorPermissionDenied
        : l10n.inviteCreateErrorGeneric(e.message ?? e.code);
    messenger?.showSnackBar(SnackBar(content: Text(msg)));
  } catch (e) {
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    messenger?.showSnackBar(
      SnackBar(content: Text(l10n.inviteCreateErrorGeneric('$e'))),
    );
  }
}

String _formatInviteExpiry(BuildContext context, int millis) {
  final localeTag = Localizations.localeOf(context).toLanguageTag();
  final d = DateTime.fromMillisecondsSinceEpoch(millis);
  return DateFormat.yMMMd(localeTag).add_Hm().format(d);
}
