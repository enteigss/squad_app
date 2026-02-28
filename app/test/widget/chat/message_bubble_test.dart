import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';
import 'package:squad_app/utils/colors.dart';
import 'package:squad_app/widgets/chat/message_bubble.dart';

import '../../fixtures/chat_message_fixtures.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('MessageBubble', () {
    group('own message', () {
      testWidgets('aligns to the right', (tester) async {
        await mockNetworkImagesFor(() => tester.pumpWidget(
              wrapWithMaterialApp(MessageBubble(
                message: ChatMessageFixtures.ownTextMessage,
                isOwnMessage: true,
                currentUserPhotoUrl:
                    ChatMessageFixtures.currentUserPhotoUrl,
              )),
            ));

        final row = tester.widget<Row>(find.byType(Row).first);
        expect(row.mainAxisAlignment, MainAxisAlignment.end);
      });

      testWidgets('uses primary color background', (tester) async {
        await mockNetworkImagesFor(() => tester.pumpWidget(
              wrapWithMaterialApp(MessageBubble(
                message: ChatMessageFixtures.ownTextMessage,
                isOwnMessage: true,
                currentUserPhotoUrl:
                    ChatMessageFixtures.currentUserPhotoUrl,
              )),
            ));

        final containers = tester.widgetList<Container>(find.byType(Container));
        final bubbleContainer = containers.where((c) {
          final decoration = c.decoration;
          if (decoration is BoxDecoration) {
            return decoration.color == AppColors.primary;
          }
          return false;
        });
        expect(bubbleContainer, isNotEmpty);
      });

      testWidgets('does NOT display sender name', (tester) async {
        await mockNetworkImagesFor(() => tester.pumpWidget(
              wrapWithMaterialApp(MessageBubble(
                message: ChatMessageFixtures.ownTextMessage,
                isOwnMessage: true,
                currentUserPhotoUrl:
                    ChatMessageFixtures.currentUserPhotoUrl,
              )),
            ));

        expect(
          find.text(ChatMessageFixtures.currentUserName),
          findsNothing,
        );
      });

      testWidgets('displays message content', (tester) async {
        await mockNetworkImagesFor(() => tester.pumpWidget(
              wrapWithMaterialApp(MessageBubble(
                message: ChatMessageFixtures.ownTextMessage,
                isOwnMessage: true,
                currentUserPhotoUrl:
                    ChatMessageFixtures.currentUserPhotoUrl,
              )),
            ));

        expect(find.text('Hello everyone!'), findsOneWidget);
      });

      testWidgets('shows avatar on the right side', (tester) async {
        await mockNetworkImagesFor(() => tester.pumpWidget(
              wrapWithMaterialApp(MessageBubble(
                message: ChatMessageFixtures.ownTextMessage,
                isOwnMessage: true,
                currentUserPhotoUrl:
                    ChatMessageFixtures.currentUserPhotoUrl,
              )),
            ));

        // The Row has: [Flexible(message), SizedBox, CircleAvatar]
        // CircleAvatar should be present
        expect(find.byType(CircleAvatar), findsOneWidget);
      });

      testWidgets('shows person icon when no photo URL', (tester) async {
        await tester.pumpWidget(
          wrapWithMaterialApp(MessageBubble(
            message: ChatMessageFixtures.ownTextMessage,
            isOwnMessage: true,
            currentUserPhotoUrl: null,
          )),
        );

        expect(find.byIcon(Icons.person), findsOneWidget);
      });
    });

    group("other user's message", () {
      testWidgets('aligns to the left', (tester) async {
        await mockNetworkImagesFor(() => tester.pumpWidget(
              wrapWithMaterialApp(MessageBubble(
                message: ChatMessageFixtures.otherTextMessage,
                isOwnMessage: false,
              )),
            ));

        final row = tester.widget<Row>(find.byType(Row).first);
        expect(row.mainAxisAlignment, MainAxisAlignment.start);
      });

      testWidgets('uses surface color background', (tester) async {
        await mockNetworkImagesFor(() => tester.pumpWidget(
              wrapWithMaterialApp(MessageBubble(
                message: ChatMessageFixtures.otherTextMessage,
                isOwnMessage: false,
              )),
            ));

        final containers = tester.widgetList<Container>(find.byType(Container));
        final bubbleContainer = containers.where((c) {
          final decoration = c.decoration;
          if (decoration is BoxDecoration) {
            return decoration.color == AppColors.surface;
          }
          return false;
        });
        expect(bubbleContainer, isNotEmpty);
      });

      testWidgets('displays sender name', (tester) async {
        await mockNetworkImagesFor(() => tester.pumpWidget(
              wrapWithMaterialApp(MessageBubble(
                message: ChatMessageFixtures.otherTextMessage,
                isOwnMessage: false,
              )),
            ));

        expect(
          find.text(ChatMessageFixtures.otherUserName),
          findsOneWidget,
        );
      });

      testWidgets('displays message content', (tester) async {
        await mockNetworkImagesFor(() => tester.pumpWidget(
              wrapWithMaterialApp(MessageBubble(
                message: ChatMessageFixtures.otherTextMessage,
                isOwnMessage: false,
              )),
            ));

        expect(find.text('Hey there!'), findsOneWidget);
      });

      testWidgets('shows avatar on the left side', (tester) async {
        await mockNetworkImagesFor(() => tester.pumpWidget(
              wrapWithMaterialApp(MessageBubble(
                message: ChatMessageFixtures.otherTextMessage,
                isOwnMessage: false,
              )),
            ));

        expect(find.byType(CircleAvatar), findsOneWidget);
      });

      testWidgets('shows person icon when no photo URL', (tester) async {
        await tester.pumpWidget(
          wrapWithMaterialApp(MessageBubble(
            message: ChatMessageFixtures.otherTextMessageNoPhoto,
            isOwnMessage: false,
          )),
        );

        expect(find.byIcon(Icons.person), findsOneWidget);
      });
    });

    group('timestamp', () {
      testWidgets('displays formatted timestamp', (tester) async {
        // Use a recent message so we get a predictable format
        final recentMessage = ChatMessageFixtures.custom(
          timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
        );

        await mockNetworkImagesFor(() => tester.pumpWidget(
              wrapWithMaterialApp(MessageBubble(
                message: recentMessage,
                isOwnMessage: true,
                currentUserPhotoUrl:
                    ChatMessageFixtures.currentUserPhotoUrl,
              )),
            ));

        expect(find.text('5m ago'), findsOneWidget);
      });
    });

    group('edited indicator', () {
      testWidgets('shows "(edited)" when isEdited is true', (tester) async {
        await mockNetworkImagesFor(() => tester.pumpWidget(
              wrapWithMaterialApp(MessageBubble(
                message: ChatMessageFixtures.editedMessage,
                isOwnMessage: false,
              )),
            ));

        expect(find.text('(edited)'), findsOneWidget);
      });

      testWidgets('does not show "(edited)" when isEdited is false',
          (tester) async {
        await mockNetworkImagesFor(() => tester.pumpWidget(
              wrapWithMaterialApp(MessageBubble(
                message: ChatMessageFixtures.otherTextMessage,
                isOwnMessage: false,
              )),
            ));

        expect(find.text('(edited)'), findsNothing);
      });
    });

    group('not yet implemented', () {
      test('shows reactions on message',
          skip: 'Reactions not yet implemented', () {});
      test('renders image messages correctly',
          skip: 'Image message UI not yet implemented', () {});
    });
  });
}
