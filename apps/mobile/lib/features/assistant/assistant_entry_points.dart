import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Abre el shell con el asistente y un mensaje inicial (§8.4).
void navigateToAssistant(
  BuildContext context, {
  String? tab,
  required String seedMessage,
}) {
  final params = <String, String>{
    'ia_open': '1',
    'ia_context': seedMessage,
  };
  if (tab != null && tab.isNotEmpty) {
    params['tab'] = tab;
  }
  context.go(Uri(path: '/app', queryParameters: params).toString());
}
