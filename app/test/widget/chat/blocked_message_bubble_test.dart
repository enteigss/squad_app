import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_app/widgets/blocked_message_bubble.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('BlockedMessageBubble', () {
    testWidgets('displays "Message from blocked user" text', (tester) async {
      await tester.pumpWidget(
        wrapWithMaterialApp(BlockedMessageBubble(
          blockedUserName: 'Blocked User',
          timestamp: DateTime.now(),
        )),
      );

      expect(find.text('Message from blocked user'), findsOneWidget);
    });

    testWidgets('shows block icon in avatar', (tester) async {
      await tester.pumpWidget(
        wrapWithMaterialApp(BlockedMessageBubble(
          blockedUserName: 'Blocked User',
          timestamp: DateTime.now(),
        )),
      );

      expect(find.byIcon(Icons.block), findsOneWidget);
    });

    testWidgets('shows visibility_off icon in message body', (tester) async {
      await tester.pumpWidget(
        wrapWithMaterialApp(BlockedMessageBubble(
          blockedUserName: 'Blocked User',
          timestamp: DateTime.now(),
        )),
      );

      expect(find.byIcon(Icons.visibility_off), findsOneWidget);
    });

    testWidgets('uses italic font style', (tester) async {
      await tester.pumpWidget(
        wrapWithMaterialApp(BlockedMessageBubble(
          blockedUserName: 'Blocked User',
          timestamp: DateTime.now(),
        )),
      );

      final text = tester.widget<Text>(
        find.text('Message from blocked user'),
      );
      expect(text.style?.fontStyle, FontStyle.italic);
    });

    testWidgets('displays timestamp', (tester) async {
      await tester.pumpWidget(
        wrapWithMaterialApp(BlockedMessageBubble(
          blockedUserName: 'Blocked User',
          timestamp: DateTime.now(),
        )),
      );

      // Recent message should show "now"
      expect(find.text('now'), findsOneWidget);
    });
  });
}
