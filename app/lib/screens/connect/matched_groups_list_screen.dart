import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/matched_group_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/matched_group_service.dart';
import '../../utils/colors.dart';
import '../../widgets/profile_avatar.dart';
import 'package:intl/intl.dart';

class MatchedGroupsListScreen extends StatefulWidget {
  final Function(MatchedGroupModel) onGroupTap;
  final VoidCallback onEditProfile;

  const MatchedGroupsListScreen({
    super.key,
    required this.onGroupTap,
    required this.onEditProfile,
  });

  @override
  State<MatchedGroupsListScreen> createState() =>
      _MatchedGroupsListScreenState();
}

class _MatchedGroupsListScreenState extends State<MatchedGroupsListScreen> {
  final MatchedGroupService _matchedGroupService = MatchedGroupService();
  final Map<String, List<UserModel>> _groupMembersCache = {};

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final userId = authProvider.currentUser?.id;

    if (userId == null) {
      return const Center(child: Text('Not logged in'));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Your Matches'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: widget.onEditProfile,
            tooltip: 'Edit matching profile',
          ),
        ],
      ),
      body: StreamBuilder<List<MatchedGroupModel>>(
        stream: _matchedGroupService.getMatchedGroupsForUser(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline,
                      size: 48, color: AppColors.textSecondary),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load matches',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          }

          final groups = snapshot.data ?? [];

          if (groups.isEmpty) {
            return _buildEmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return _buildGroupCard(context, group, userId);
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.hourglass_empty,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Matches Yet',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'We\'re working on finding you the perfect group. '
              'Check back soon!',
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: widget.onEditProfile,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit your profile'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupCard(
    BuildContext context,
    MatchedGroupModel group,
    String currentUserId,
  ) {
    return FutureBuilder<List<UserModel>>(
      future: _getGroupMembers(group, currentUserId),
      builder: (context, snapshot) {
        final members = snapshot.data ?? [];
        final otherMembers =
            members.where((m) => m.id != currentUserId).toList();

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppColors.divider),
          ),
          child: InkWell(
            onTap: () => widget.onGroupTap(group),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Member avatars (stacked)
                  _buildMemberAvatars(otherMembers),
                  const SizedBox(width: 16),
                  // Group info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getGroupDisplayName(group, otherMembers),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (group.lastMessagePreview != null) ...[
                          Text(
                            group.lastMessagePreview!,
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ] else ...[
                          Text(
                            'Start a conversation!',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.primary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Timestamp and arrow
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (group.lastMessageTime != null)
                        Text(
                          _formatTimestamp(group.lastMessageTime!),
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Icon(
                        Icons.chevron_right,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMemberAvatars(List<UserModel> members) {
    if (members.isEmpty) {
      return ProfileAvatar(
        radius: 28,
        name: '?',
      );
    }

    if (members.length == 1) {
      return ProfileAvatar(
        radius: 28,
        imageUrl: members[0].photoUrl,
        name: members[0].displayName,
      );
    }

    // Stack multiple avatars
    const double avatarRadius = 22;
    const double overlap = 16;
    final int displayCount = members.length > 3 ? 3 : members.length;
    final double totalWidth =
        (avatarRadius * 2) + (overlap * (displayCount - 1));

    return SizedBox(
      width: totalWidth,
      height: avatarRadius * 2,
      child: Stack(
        children: List.generate(displayCount, (index) {
          return Positioned(
            left: index * overlap,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 2),
              ),
              child: ProfileAvatar(
                radius: avatarRadius - 2,
                imageUrl: members[index].photoUrl,
                name: members[index].displayName,
              ),
            ),
          );
        }),
      ),
    );
  }

  Future<List<UserModel>> _getGroupMembers(
    MatchedGroupModel group,
    String currentUserId,
  ) async {
    // Check cache first
    if (_groupMembersCache.containsKey(group.id)) {
      return _groupMembersCache[group.id]!;
    }

    final members = await _matchedGroupService.getGroupMembers(group.memberIds);
    _groupMembersCache[group.id] = members;
    return members;
  }

  String _getGroupDisplayName(MatchedGroupModel group, List<UserModel> others) {
    if (group.name.isNotEmpty && group.name != 'New Match') {
      return group.name;
    }

    if (others.isEmpty) {
      return 'Your Match';
    }

    if (others.length == 1) {
      return others[0].displayName ?? 'Your Match';
    }

    final names = others.take(2).map((m) => m.displayName ?? 'Someone').toList();
    if (others.length > 2) {
      return '${names.join(', ')} +${others.length - 2}';
    }
    return names.join(' & ');
  }

  String _formatTimestamp(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays == 0) {
      return DateFormat.jm().format(time);
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return DateFormat.E().format(time);
    } else {
      return DateFormat.MMMd().format(time);
    }
  }
}
