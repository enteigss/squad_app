import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../../models/post_model.dart';
import '../../models/post_chat_message.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/post_chat_service.dart';
import '../../services/block_service.dart';
import '../../services/navigation_service.dart';
import '../../utils/colors.dart';
import '../../widgets/custom_button.dart';

class PostChatScreen extends StatefulWidget {
  final Post post;

  const PostChatScreen({
    super.key,
    required this.post,
  });

  @override
  State<PostChatScreen> createState() => _PostChatScreenState();
}

class _PostChatScreenState extends State<PostChatScreen> {
  final PostChatService _chatService = PostChatService();
  final BlockService _blockService = BlockService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _canAccessChat = false;
  bool _isReadOnly = false;
  String? _error;
  UserModel? _currentUser;
  StreamSubscription<DocumentSnapshot>? _userSubscription;

  @override
  void initState() {
    super.initState();
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _currentUser = authProvider.currentUser;

    // Listen to user document for real-time block updates
    if (_currentUser != null) {
      _userSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUser!.id)
          .snapshots()
          .listen((snapshot) {
        if (snapshot.exists && mounted) {
          setState(() {
            _currentUser = UserModel.fromMap(snapshot.data()!);
          });
          debugPrint('🔄 PostChat: User data updated, blocked lists refreshed');
        }
      });
    }

    _checkChatAccess();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _userSubscription?.cancel();
    super.dispose();
  }

  List<PostChatMessage> _filterBlockedMessages(List<PostChatMessage> messages) {
    if (_currentUser == null) {
      return messages;
    }

    // Filter out messages from blocked users
    return messages.where((message) {
      final shouldFilter = _blockService.shouldFilterContent(
        message.senderId,
        _currentUser!.blockedUserIds,
        _currentUser!.blockedByUserIds,
      );

      if (shouldFilter) {
        debugPrint('🚫 PostChat: Filtering message from blocked user ${message.senderName} (${message.senderId})');
      }

      return !shouldFilter;
    }).toList();
  }

  Future<void> _checkChatAccess() async {
    final currentUserId = Provider.of<AuthProvider>(context, listen: false).currentUser?.id;
    
    if (currentUserId == null) {
      setState(() {
        _error = 'You must be logged in to access chat';
        _isLoading = false;
      });
      return;
    }

    try {
      final canAccess = await _chatService.canAccessChat(widget.post.id, currentUserId);
      final isReadOnly = await _chatService.isChatReadOnly(widget.post.id);

      setState(() {
        _canAccessChat = canAccess;
        _isReadOnly = isReadOnly;
        _isLoading = false;
      });

      if (canAccess) {
        // Mark messages as read when user opens chat
        _chatService.markMessagesAsRead(widget.post.id, currentUserId);
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load chat: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Use stack navigation to pop back to previous screen
            Navigator.of(context).pop();
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.post.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Group Chat',
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.8),
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Chat status indicator
          if (_isReadOnly)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: AppColors.textSecondary.withValues(alpha: 0.1),
              child: Text(
                'This event has ended. Chat is read-only.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ),
          
          // Messages area
          Expanded(
            child: _buildMessagesArea(),
          ),
          
          // Message input
          if (!_isReadOnly && _canAccessChat)
            _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessagesArea() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Error loading chat',
              style: TextStyle(fontSize: 18, color: AppColors.error),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _checkChatAccess,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (!_canAccessChat) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline,
              size: 64,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Access Denied',
              style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              'You must be a participant in this event to access the chat.',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return StreamBuilder<List<PostChatMessage>>(
      stream: _chatService.getChatMessages(widget.post.id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading messages: ${snapshot.error}',
              style: TextStyle(color: AppColors.error),
            ),
          );
        }

        final allMessages = snapshot.data ?? [];

        // Filter out messages from blocked users
        final messages = _filterBlockedMessages(allMessages);

        if (messages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 64,
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No messages yet',
                  style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Text(
                  'Be the first to say hello!',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          controller: _scrollController,
          reverse: true, // Show newest messages at bottom
          padding: const EdgeInsets.all(16),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            return _buildMessageBubble(message);
          },
        );
      },
    );
  }

  Widget _buildMessageBubble(PostChatMessage message) {
    final currentUserId = Provider.of<AuthProvider>(context, listen: false).currentUser?.id;
    final isOwnMessage = message.senderId == currentUserId;
    final isSystemMessage = message.type == PostChatMessageType.system;

    if (isSystemMessage) {
      return _buildSystemMessage(message);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: isOwnMessage ? MainAxisAlignment.end : MainAxisAlignment.start,
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
                  bottomRight: isOwnMessage ? const Radius.circular(4) : null,
                  bottomLeft: !isOwnMessage ? const Radius.circular(4) : null,
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
                      color: isOwnMessage ? Colors.white : AppColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatMessageTime(message.timestamp),
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
          if (isOwnMessage) const SizedBox(width: 40),
        ],
      ),
    );
  }

  Widget _buildSystemMessage(PostChatMessage message) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.textSecondary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            message.content,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(
          top: BorderSide(
            color: AppColors.textSecondary.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.7)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    final currentUser = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (currentUser == null) return;

    try {
      await _chatService.sendMessage(
        postId: widget.post.id,
        senderId: currentUser.id,
        senderName: currentUser.displayName ?? 'Unknown User',
        content: message,
        senderPhotoUrl: currentUser.photoUrl,
      );

      _messageController.clear();
      
      // Scroll to bottom after sending
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0, // Since we're using reverse: true, 0 is the bottom
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String _formatMessageTime(DateTime timestamp) {
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