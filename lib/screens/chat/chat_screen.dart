import 'package:flutter/material.dart';
import 'package:squad_app/models/message_model.dart';
import '../../utils/colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/message_bubble.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class ChatScreen extends StatefulWidget {
  final String? groupId; // Optional - will get from user if not provided

  const ChatScreen({super.key, this.groupId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  Stream<List<MessageModel>>? _messageStream;
  String? _currentGroupId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    await _getCurrentGroupId();
    if (_currentGroupId != null) {
      _setupMessageStream();
    }
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _getCurrentGroupId() async {
    // Use provided groupId if available
    if (widget.groupId != null) {
      _currentGroupId = widget.groupId;
      return;
    }

    // Otherwise get from current user
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;

    if (currentUser?.groupId != null) {
      _currentGroupId = currentUser!.groupId;
    } else {
      print('⚠️ No groupId found for current user');
    }
  }

  void _setupMessageStream() {
    if (_currentGroupId == null) return;

    print('🔥 Setting up message stream for groupId: $_currentGroupId');

    _messageStream = FirebaseFirestore.instance
        .collection('groups')
        .doc(_currentGroupId!)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) {
            print('No documents found in the stream');
          }

          final messages = snapshot.docs.map((doc) {
            try {
              return MessageModel.fromMap(doc.data());
            } catch (e) {
              print('Error parsing message: $e');
              print('Document data: ${doc.data()}');
              rethrow;
            }
          }).toList();

          return messages;
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primaryLight,
              child: Icon(Icons.group, size: 18, color: AppColors.onPrimary),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Squad Chat',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Text(
                  '4 members',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.onPrimary.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _currentGroupId == null
                ? const Center(
                    child: Text(
                      'No group found for this user',
                      style: TextStyle(color: Colors.red),
                    ),
                  )
                : StreamBuilder<List<MessageModel>>(
                    stream: _messageStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        print('🔥 Error: ${snapshot.error}');
                      }
                      if (snapshot.hasData) {
                        print('🔥 Data length: ${snapshot.data!.length}');
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        print('🔥 Showing error: ${snapshot.error}');
                        return Center(
                          child: Text(
                            'Error loading messages: ${snapshot.error}',
                          ),
                        );
                      }

                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(
                          child: Text(
                            'No messages yet. Start the conversation!',
                            style: TextStyle(color: Colors.grey),
                          ),
                        );
                      }

                      final messages = snapshot.data!;

                      return ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(16),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final authProvider = Provider.of<AuthProvider>(
                            context,
                            listen: false,
                          );
                          final currentUserId =
                              authProvider.currentUser?.id ?? '';

                          return MessageBubble(
                            message: message,
                            currentUserId: currentUserId,
                          );
                        },
                      );
                    },
                  ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider, width: 1)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.attach_file),
            color: AppColors.textSecondary,
            onPressed: () {},
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.inputBackground,
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send,
                color: AppColors.onPrimary,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;

    if (currentUser == null) return;

    final messageText = _messageController.text.trim();
    _messageController.clear();

    try {
      final messageData = {
        'id': DateTime.now().millisecondsSinceEpoch.toString(),
        'groupId': _currentGroupId,
        'senderId': currentUser.id,
        'senderName': currentUser.displayName ?? currentUser.username,
        'senderAvatar': currentUser.photoUrl,
        'content': messageText,
        'type': 'text',
        'timestamp': FieldValue.serverTimestamp(),
        'readBy': [currentUser.id],
        'isEdited': false,
      };

      await FirebaseFirestore.instance
          .collection('groups')
          .doc(_currentGroupId!)
          .collection('messages')
          .add(messageData);
    } catch (e) {
      // Handle error - could show a snackbar
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send message: $e')));
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
