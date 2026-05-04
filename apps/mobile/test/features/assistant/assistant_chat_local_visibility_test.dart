import 'package:oga/features/assistant/assistant_chat_local_visibility.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('serverStoredClientMessageIds', () {
    test('collects clientMessageId and clientMessageIds list', () {
      final ids = serverStoredClientMessageIds([
        {'clientMessageId': ' a ', 'role': 'user'},
        {'clientMessageIds': ['x', '', 'y'], 'role': 'user'},
      ]);
      expect(ids, {'a', 'x', 'y'});
    });
  });

  group('shouldShowLocalUserBubble', () {
    test('failed always visible', () {
      expect(
        shouldShowLocalUserBubble(
          isFailed: true,
          isSent: false,
          clientMessageId: 'c1',
          serverClientIds: {'c1'},
        ),
        true,
      );
    });

    test('sent never visible', () {
      expect(
        shouldShowLocalUserBubble(
          isFailed: false,
          isSent: true,
          clientMessageId: 'c1',
          serverClientIds: {},
        ),
        false,
      );
    });

    test('pending hidden when server echoed id', () {
      expect(
        shouldShowLocalUserBubble(
          isFailed: false,
          isSent: false,
          clientMessageId: 'c1',
          serverClientIds: {'c1'},
        ),
        false,
      );
    });

    test('pending visible when not on server', () {
      expect(
        shouldShowLocalUserBubble(
          isFailed: false,
          isSent: false,
          clientMessageId: 'c1',
          serverClientIds: {'other'},
        ),
        true,
      );
    });
  });
}
