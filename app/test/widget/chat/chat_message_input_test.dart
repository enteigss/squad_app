import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:squad_app/widgets/chat/chat_message_input.dart';

import '../../helpers/test_helpers.dart';

void main() {
  group('ChatMessageInput', () {
    late TextEditingController controller;
    bool onSendCalled = false;

    setUp(() {
      controller = TextEditingController();
      onSendCalled = false;
    });

    tearDown(() {
      controller.dispose();
    });

    Widget buildWidget() {
      return wrapWithScaffold(
        ChatMessageInput(
          controller: controller,
          onSend: () => onSendCalled = true,
        ),
      );
    }

    group('text field', () {
      testWidgets('renders with hint "Type a message..."', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(find.text('Type a message...'), findsOneWidget);
      });

      testWidgets('accepts text input', (tester) async {
        await tester.pumpWidget(buildWidget());

        await tester.enterText(find.byType(TextField), 'Hello!');
        await tester.pump();

        expect(controller.text, 'Hello!');
      });
    });

    group('send button', () {
      testWidgets('renders send icon', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(find.byIcon(Icons.send), findsOneWidget);
      });

      testWidgets('calls onSend when tapped', (tester) async {
        await tester.pumpWidget(buildWidget());

        await tester.tap(find.byIcon(Icons.send));
        await tester.pump();

        expect(onSendCalled, isTrue);
      });

      testWidgets('calls onSend on field submission', (tester) async {
        await tester.pumpWidget(buildWidget());

        await tester.enterText(find.byType(TextField), 'Test message');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pump();

        expect(onSendCalled, isTrue);
      });
    });

    group('not yet implemented', () {
      test('send button is disabled when text field is empty',
          skip: 'Send button has no disabled state', () {});
      test('image attachment button exists',
          skip: 'Image attachment not yet implemented', () {});
    });
  });
}
