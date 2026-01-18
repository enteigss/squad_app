import 'package:flutter/material.dart';
import '../models/message_model.dart';
import '../utils/colors.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final String currentUserId;

  const MessageBubble({
    super.key,
    required this.message,
    required this.currentUserId,
  });

  bool get isOwn => message.senderId == currentUserId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isOwn
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isOwn) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.getAvatarColor(message.senderName),
              backgroundImage: message.senderAvatar != null
                  ? NetworkImage(message.senderAvatar!)
                  : null,
              child: message.senderAvatar == null
                  ? Text(
                      message.senderName[0].toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.onPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isOwn
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                if (!isOwn)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      message.senderName,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                _buildMessageContent(),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTimestamp(message.timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (message.isEdited) ...[
                        const SizedBox(width: 4),
                        Text(
                          '(edited)',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isOwn) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary,
              backgroundImage: message.senderAvatar != null
                  ? NetworkImage(message.senderAvatar!)
                  : null,
              child: message.senderAvatar == null
                  ? Text(
                      message.senderName[0].toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.onPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageContent() {
    switch (message.type) {
      case MessageType.text:
        return _buildTextMessage();
      case MessageType.image:
        return _buildImageMessage();
      case MessageType.file:
        return _buildFileMessage();
      case MessageType.system:
        return _buildSystemMessage();
    }
  }

  Widget _buildTextMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isOwn ? AppColors.chatBubbleOwn : AppColors.chatBubbleOther,
        borderRadius: BorderRadius.circular(16).copyWith(
          bottomLeft: isOwn
              ? const Radius.circular(16)
              : const Radius.circular(4),
          bottomRight: isOwn
              ? const Radius.circular(4)
              : const Radius.circular(16),
        ),
      ),
      child: Text(
        message.content,
        style: TextStyle(
          color: isOwn ? AppColors.onPrimary : AppColors.textPrimary,
          fontSize: 14,
        ),
      ),
    );
  }

  Widget _buildImageMessage() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.imageUrl != null)
          Container(
            constraints: const BoxConstraints(maxWidth: 250, maxHeight: 300),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isOwn
                  ? AppColors.chatBubbleOwn
                  : AppColors.chatBubbleOther,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                message.imageUrl!,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 200,
                    width: 250,
                    decoration: BoxDecoration(
                      color: AppColors.inputBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 200,
                    width: 250,
                    decoration: BoxDecoration(
                      color: AppColors.inputBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Center(child: Icon(Icons.error)),
                  );
                },
              ),
            ),
          ),
        if (message.content.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _buildTextMessage(),
          ),
      ],
    );
  }

  Widget _buildFileMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isOwn ? AppColors.chatBubbleOwn : AppColors.chatBubbleOther,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.attach_file,
            color: isOwn ? AppColors.onPrimary : AppColors.textPrimary,
            size: 20,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message.fileName ?? 'File',
                  style: TextStyle(
                    color: isOwn ? AppColors.onPrimary : AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (message.fileSize != null)
                  Text(
                    _formatFileSize(message.fileSize!),
                    style: TextStyle(
                      color: isOwn
                          ? AppColors.onPrimary.withValues(alpha: 0.7)
                          : AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSystemMessage() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.inputBackground,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message.content,
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
