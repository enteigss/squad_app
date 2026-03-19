import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_app/widgets/chat/system_message_bubble.dart';

import '../../fixtures/chat_message_fixtures.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('SystemMessageBubble', () {
    testWidgets('displays message content', (tester) async {
      await tester.pumpWidget(
        wrapWithMaterialApp(
          SystemMessageBubble(message: ChatMessageFixtures.systemMessage),
        ),
      );

      expect(find.text('Alice joined the group'), findsOneWidget);
    });

    testWidgets('text is centered', (tester) async {
      await tester.pumpWidget(
        wrapWithMaterialApp(
          SystemMessageBubble(message: ChatMessageFixtures.systemMessage),
        ),
      );

      expect(find.byType(Center), findsOneWidget);

      final text = tester.widget<Text>(find.text('Alice joined the group'));
      expect(text.textAlign, TextAlign.center);
    });

    testWidgets('uses italic font style', (tester) async {
      await tester.pumpWidget(
        wrapWithMaterialApp(
          SystemMessageBubble(message: ChatMessageFixtures.systemMessage),
        ),
      );

      final text = tester.widget<Text>(find.text('Alice joined the group'));
      expect(text.style?.fontStyle, FontStyle.italic);
    });
  });
}
