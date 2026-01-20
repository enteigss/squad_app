import 'package:flutter/material.dart';
import '../../models/post_model.dart';
import '../chat/chat_screen.dart';

/// Wrapper for backward compatibility.
/// Use ChatScreen.forHangout directly for new code.
@Deprecated('Use ChatScreen.forHangout instead')
class PostChatScreen extends StatelessWidget {
  final Post post;

  const PostChatScreen({
    super.key,
    required this.post,
  });

  @override
  Widget build(BuildContext context) {
    return ChatScreen.forHangout(post: post);
  }
}
