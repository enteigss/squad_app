import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import '../../models/chat_message.dart';
import '../../models/post_model.dart';
import '../../models/matched_group_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/chat_service.dart';
import '../../services/block_service.dart';
import '../../services/notification_service.dart';
import '../../services/navigation_service.dart';
import '../../utils/colors.dart';
import '../../widgets/blocked_message_bubble.dart';
import '../../widgets/chat/message_bubble.dart';
import '../../widgets/chat/system_message_bubble.dart';
import '../../widgets/chat/chat_message_input.dart';

/// Configuration for the chat screen
class ChatScreenConfig {
  final ChatContext context;
  final String chatRoomId;
  final String title;
  final String? subtitle;
  final String? fallbackNavigationPath;

  const ChatScreenConfig({
    required this.context,
    required this.chatRoomId,
    required this.title,
    this.subtitle,
    this.fallbackNavigationPath,
  });
}

/// Generic chat screen that works for both hangout posts and matched groups
class ChatScreen extends StatefulWidget {
  final ChatScreenConfig config;

  const ChatScreen({super.key, required this.config});

  /// Factory constructor for hangout (post) chats
  factory ChatScreen.forHangout({required Post post}) {
    return ChatScreen(
      config: ChatScreenConfig(
        context: ChatContext.hangout,
        chatRoomId: post.id,
        title: 'Group Chat',
        fallbackNavigationPath: '/group-members/${post.id}',
      ),
    );
  }

  /// Factory constructor for matched group chats
  factory ChatScreen.forMatchedGroup({required MatchedGroupModel group}) {
    return ChatScreen(
      config: ChatScreenConfig(
        context: ChatContext.matchedGroup,
        chatRoomId: group.id,
        title: group.name,
        subtitle: '${group.memberCount} members',
        fallbackNavigationPath: '/matched-groups',
      ),
    );
  }

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final BlockService _blockService = BlockService();
  final NotificationService _notificationService = NotificationService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  bool _canAccessChat = false;
  bool _isReadOnly = false;
  String? _error;
  UserModel? _currentUser;
  StreamSubscription<DocumentSnapshot>? _userSubscription;
  bool _chatNotificationsEnabled = true;
  bool _loadingNotificationPref = false;

  ChatContext get _context => widget.config.context;
  String get _chatRoomId => widget.config.chatRoomId;

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
              debugPrint('🔄 Chat: User data updated, blocked lists refreshed');
            }
          });
    }

    _checkChatAccess();
    _loadNotificationPreference();
  }

  Future<void> _loadNotificationPreference() async {
    // Only load notification preferences for hangout chats for now
    if (_context != ChatContext.hangout) return;

    try {
      final enabled = await _notificationService
          .getHangoutChatNotificationPreference(_chatRoomId);
      if (mounted) {
        setState(() {
          _chatNotificationsEnabled = enabled;
        });
      }
    } catch (e) {
      debugPrint('Error loading notification preference: $e');
    }
  }

  Future<void> _toggleChatNotifications() async {
    if (_loadingNotificationPref) return;

    // Optimistic update
    final previousValue = _chatNotificationsEnabled;
    setState(() {
      _chatNotificationsEnabled = !_chatNotificationsEnabled;
      _loadingNotificationPref = true;
    });

    try {
      if (_context == ChatContext.hangout) {
        await _notificationService.toggleHangoutChatNotifications(
          _chatRoomId,
          _chatNotificationsEnabled,
        );
      }

      if (mounted) {
        setState(() {
          _loadingNotificationPref = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _chatNotificationsEnabled
                  ? 'Chat notifications enabled'
                  : 'Chat notifications disabled',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Rollback on error
      if (mounted) {
        setState(() {
          _chatNotificationsEnabled = previousValue;
          _loadingNotificationPref = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update notification settings'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      debugPrint('Error toggling chat notifications: $e');
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _userSubscription?.cancel();
    super.dispose();
  }

  List<ChatMessage> _filterBlockedMessages(List<ChatMessage> messages) {
    if (_currentUser == null) {
      return messages;
    }

    return messages.map((message) {
      final shouldCensor = _blockService.shouldCensorContent(
        message.senderId,
        _currentUser!.blockedUserIds,
        _currentUser!.blockedByUserIds,
      );

      if (shouldCensor) {
        debugPrint(
          '🚫 Chat: Censoring message from blocked user ${message.senderName} (${message.senderId})',
        );
        return message.copyWith(content: 'CENSORED_MESSAGE');
      }

      return message;
    }).toList();
  }

  Future<void> _checkChatAccess() async {
    final currentUserId = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).currentUser?.id;

    if (currentUserId == null) {
      setState(() {
        _error = 'You must be logged in to access chat';
        _isLoading = false;
      });
      return;
    }

    try {
      final canAccess = await _chatService.canAccessChat(
        _context,
        _chatRoomId,
        currentUserId,
      );
      final isReadOnly = await _chatService.isChatReadOnly(
        _context,
        _chatRoomId,
      );

      setState(() {
        _canAccessChat = canAccess;
        _isReadOnly = isReadOnly;
        _isLoading = false;
      });

      if (canAccess) {
        // Mark messages as read when user opens chat
        _chatService.markMessagesAsRead(_context, _chatRoomId, currentUserId);
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
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            } else if (widget.config.fallbackNavigationPath != null) {
              NavigationService.goToPath(widget.config.fallbackNavigationPath!);
            }
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.config.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            if (widget.config.subtitle != null)
              Text(
                widget.config.subtitle!,
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
        actions: [
          if (_canAccessChat)
            IconButton(
              icon: Icon(
                _chatNotificationsEnabled
                    ? Icons.notifications
                    : Icons.notifications_off,
              ),
              onPressed: _toggleChatNotifications,
              tooltip: _chatNotificationsEnabled
                  ? 'Disable chat notifications'
                  : 'Enable chat notifications',
            ),
        ],
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
                _context == ChatContext.hangout
                    ? 'This event has ended. Chat is read-only.'
                    : 'This group has been archived. Chat is read-only.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
            ),

          // Messages area
          Expanded(child: _buildMessagesArea()),

          // Message input
          if (!_isReadOnly && _canAccessChat) _buildMessageInput(),
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
              _context == ChatContext.hangout
                  ? 'You must be a participant in this event to access the chat.'
                  : 'You must be a member of this group to access the chat.',
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

    return StreamBuilder<List<ChatMessage>>(
      stream: _chatService.getMessages(_context, _chatRoomId),
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
                  style: TextStyle(
                    fontSize: 18,
                    color: AppColors.textSecondary,
                  ),
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
          reverse: true,
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

  Widget _buildMessageBubble(ChatMessage message) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.id;
    final currentUserPhotoUrl = authProvider.currentUser?.photoUrl;
    final isOwnMessage = message.senderId == currentUserId;

    if (message.type == ChatMessageType.system) {
      return SystemMessageBubble(message: message);
    }

    if (message.content == 'CENSORED_MESSAGE') {
      return BlockedMessageBubble(
        blockedUserName: message.senderName,
        timestamp: message.timestamp,
      );
    }

    return MessageBubble(
      message: message,
      isOwnMessage: isOwnMessage,
      currentUserPhotoUrl: currentUserPhotoUrl,
    );
  }

  Widget _buildMessageInput() {
    return ChatMessageInput(
      controller: _messageController,
      onSend: _sendMessage,
    );
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    final currentUser = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).currentUser;
    if (currentUser == null) return;

    try {
      await _chatService.sendMessage(
        context: _context,
        chatRoomId: _chatRoomId,
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
}
