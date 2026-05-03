import 'dart:convert';

import 'package:craftr_mobile/services/functions_region.dart';
import 'package:http/http.dart' as http;

/// Cliente de invocaciones a Firebase Functions para el asistente.
class AssistantFunctionsClient {
  AssistantFunctionsClient({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  final http.Client _httpClient;

  Future<void> renameAssistantThreadTitle({
    required String familyId,
    required String threadId,
    required String conversationTitle,
  }) async {
    final callable = craftrFunctions().httpsCallable('renameAssistantThreadTitle');
    await callable.call({
      'familyId': familyId,
      'threadId': threadId,
      'conversationTitle': conversationTitle,
    });
  }

  Stream<Map<String, dynamic>> streamAssistantChat({
    required String idToken,
    required String familyId,
    String? threadId,
    required String message,
    required List<String> clientMessageIds,
    required int bufferSize,
    required int delayMs,
    required int tokensSavedEstimated,
  }) async* {
    final request = http.Request('POST', Uri.parse(familyAssistantStreamUrl()));
    request.headers['Authorization'] = 'Bearer $idToken';
    request.headers['Content-Type'] = 'application/json; charset=utf-8';
    request.body = jsonEncode({
      'familyId': familyId,
      if (threadId != null && threadId.isNotEmpty) 'threadId': threadId,
      'message': message,
      'clientMessageIds': clientMessageIds,
      'batchMeta': {
        'buffer_size': bufferSize,
        'delay_ms': delayMs,
        'tokens_saved_estimados': tokensSavedEstimated,
      },
    });

    final response = await _httpClient.send(request);
    if (response.statusCode != 200) {
      final buf = StringBuffer();
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        buf.write(chunk);
      }
      throw Exception('HTTP ${response.statusCode}: ${buf.toString()}');
    }

    await for (final line in response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      if (line.isEmpty) {
        continue;
      }
      final decoded = jsonDecode(line);
      if (decoded is Map<String, dynamic>) {
        yield decoded;
      }
    }
  }

  void dispose() {
    _httpClient.close();
  }
}
