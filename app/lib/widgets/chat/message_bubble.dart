import 'package:flutter/material.dart';
import '../../models/chat_message.dart';
import '../../utils/colors.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isOwnMessage;
  final String? currentUserPhotoUrl;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isOwnMessage,
    this.currentUserPhotoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            isOwnMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isOwnMessage) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              backgroundImage: message.senderPhotoUrl != null
                  ? NetworkImage(message.senderPhotoUrl!)
                  : null,
              child: message.senderPhotoUrl == null
                  ? Icon(Icons.person, color: AppColors.primary, size: 16)
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isOwnMessage ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomRight:
                      isOwnMessage ? const Radius.circular(4) : null,
                  bottomLeft:
                      !isOwnMessage ? const Radius.circular(4) : null,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isOwnMessage)
                    Text(
                      message.senderName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  if (!isOwnMessage) const SizedBox(height: 4),
                  Text(
                    message.content,
                    style: TextStyle(
                      color: isOwnMessage
                          ? Colors.white
                          : AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatMessageTime(message.timestamp),
                        style: TextStyle(
                          fontSize: 10,
                          color: isOwnMessage
                              ? Colors.white.withValues(alpha: 0.7)
                              : AppColors.textSecondary,
                        ),
                      ),
                      if (message.isEdited) ...[
                        const SizedBox(width: 4),
                        Text(
                          '(edited)',
                          style: TextStyle(
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                            color: isOwnMessage
                                ? Colors.white.withValues(alpha: 0.7)
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isOwnMessage) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              backgroundImage: currentUserPhotoUrl != null
                  ? NetworkImage(currentUserPhotoUrl!)
                  : null,
              child: currentUserPhotoUrl == null
                  ? Icon(Icons.person, color: AppColors.primary, size: 16)
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  static String formatMessageTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }
}
