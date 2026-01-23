import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/matched_group_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/matched_group_service.dart';
import '../../utils/colors.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/profile_avatar.dart';
import '../chat/chat_screen.dart';

class MatchedGroupInfoScreen extends StatefulWidget {
  final MatchedGroupModel group;
  final VoidCallback onBack;

  const MatchedGroupInfoScreen({
    super.key,
    required this.group,
    required this.onBack,
  });

  @override
  State<MatchedGroupInfoScreen> createState() => _MatchedGroupInfoScreenState();
}

class _MatchedGroupInfoScreenState extends State<MatchedGroupInfoScreen> {
  final MatchedGroupService _matchedGroupService = MatchedGroupService();
  List<UserModel> _members = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.id ?? '';

    final members = await _matchedGroupService.getOtherGroupMembers(
      widget.group.memberIds,
      currentUserId,
    );

    if (mounted) {
      setState(() {
        _members = members;
        _isLoading = false;
      });
    }
  }

  void _navigateToChat() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ChatScreen.forMatchedGroup(group: widget.group),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Your Match'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack,
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header celebration
                  _buildHeader(),
                  // Members section
                  _buildMembersSection(),
                  // Suggestion cards
                  if (widget.group.activitySuggestion != null)
                    _buildSuggestionCard(
                      icon: Icons.local_activity_outlined,
                      title: 'Activity Suggestion',
                      description: 'Based on your schedules and shared interests. Feel free to do something else!',
                      content: widget.group.activitySuggestion!,
                      color: AppColors.success,
                    ),
                  if (widget.group.sharedInterests != null)
                    _buildSuggestionCard(
                      icon: Icons.link,
                      title: 'What You Have in Common',
                      description: 'Things you all share an interest in.',
                      content: widget.group.sharedInterests!,
                      color: AppColors.primary,
                    ),
                  // Spacer for button
                  const SizedBox(height: 100),
                ],
              ),
            ),
      bottomNavigationBar: _buildChatButton(),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primary.withValues(alpha: 0.1),
            AppColors.background,
          ],
        ),
      ),
      child: Column(
        children: [
          // Stacked avatars
          _buildStackedAvatars(),
          const SizedBox(height: 16),
          Text(
            'Here\'s Your Group!',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _getMembersDescription(),
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStackedAvatars() {
    if (_members.isEmpty) {
      return ProfileAvatar(radius: 40, name: '?');
    }

    if (_members.length == 1) {
      return ProfileAvatar(
        radius: 50,
        imageUrl: _members[0].photoUrl,
        name: _members[0].displayName,
      );
    }

    // Stack multiple avatars in a circle pattern
    const double avatarRadius = 40;

    return SizedBox(
      width: 140,
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: List.generate(_members.length.clamp(0, 3), (index) {
          double offsetX = 0;
          if (_members.length >= 2) {
            offsetX = index == 0 ? -25 : (index == 1 ? 25 : 0);
          }
          double offsetY = index == 2 ? 20 : 0;

          return Positioned(
            left: 70 + offsetX - avatarRadius,
            top: 50 + offsetY - avatarRadius,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ProfileAvatar(
                radius: avatarRadius - 3,
                imageUrl: _members[index].photoUrl,
                name: _members[index].displayName,
              ),
            ),
          );
        }),
      ),
    );
  }

  String _getMembersDescription() {
    if (_members.isEmpty) {
      return 'Get ready to meet your new friends!';
    }

    if (_members.length == 1) {
      return 'Meet ${_members[0].displayName ?? 'your new friend'}!';
    }

    final names = _members.map((m) => m.displayName ?? 'Someone').toList();
    if (names.length == 2) {
      return 'Meet ${names[0]} and ${names[1]}!';
    }
    return 'Meet ${names.take(2).join(', ')} and ${names.length - 2} more!';
  }

  Widget _buildMembersSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Group Members',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          ..._members.map((member) => _buildMemberCard(member)),
        ],
      ),
    );
  }

  Widget _buildMemberCard(UserModel member) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          ProfileAvatar(
            radius: 30,
            imageUrl: member.photoUrl,
            name: member.displayName,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.displayName ?? 'Anonymous',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (member.bio != null && member.bio!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    member.bio!,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (member.classYear != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.school_outlined,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Class of ${member.classYear}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard({
    required IconData icon,
    required String title,
    required String content,
    required Color color,
    String? description,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          if (description != null) ...[
            const SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            content,
            style: const TextStyle(
              fontSize: 15,
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: CustomButton(
          text: 'Start Chatting',
          onPressed: _navigateToChat,
          width: double.infinity,
          icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
        ),
      ),
    );
  }
}
