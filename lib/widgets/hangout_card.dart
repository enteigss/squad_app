import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../providers/post_provider.dart';
import '../services/firestore_service.dart';
import '../services/analytics_service.dart';
import '../utils/colors.dart';
import '../widgets/profile_avatar.dart';
import '../widgets/meetup_outcome_dialog.dart';

class HangoutCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onDeleted;

  const HangoutCard({super.key, required this.post, this.onDeleted});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _handleTap(context),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              // Main content
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: Profile picture + name (author only)
                  _buildTopRow(context),

                  const SizedBox(height: 16),

                  // Middle section: Title, location, description
                  _buildMiddleSection(),

                  const SizedBox(height: 16),

                  // Bottom row: Group member count + author actions
                  _buildBottomRow(),
                ],
              ),

              // Status positioned in top right corner
              Positioned(top: 0, right: 0, child: _buildStatusElement()),

              // Menu positioned in bottom right corner (for authors only)
              Positioned(bottom: -8, right: -8, child: _buildPostMenu(context)),
            ],
          ),
        ),
      ),
    );
  }

  void _handleTap(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.id;
    if (currentUserId == null) return;

    context.push('/group-members/${post.id}');
  }

  Widget _buildTopRow(BuildContext context) {
    return Row(
      children: [
        // Profile picture and name (author info only)
        Row(
          children: [
            // Profile picture
            _buildProfilePicture(post.authorId),
            const SizedBox(width: 8),
            // Name
            Text(
              post.authorName,
              style: TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),

        // Close indicator (if closed)
        if (post.isLocked) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: AppColors.textSecondary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock,
                  size: 8,
                  color: AppColors.textSecondary.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 2),
                Text(
                  'Closed',
                  style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                    fontSize: 8,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProfilePicture(String authorId) {
    return FutureBuilder<UserModel?>(
      future: _getUserData(authorId),
      builder: (context, snapshot) {
        final user = snapshot.data;

        return ProfileAvatar(
          imageUrl: user?.photoUrl,
          name: user?.displayName ?? user?.username,
          radius: 14,
          backgroundColor: AppColors.textSecondary.withValues(alpha: 0.1),
          textColor: AppColors.textSecondary.withValues(alpha: 0.7),
        );
      },
    );
  }

  Future<UserModel?> _getUserData(String userId) async {
    try {
      final firestoreService = FirestoreService();
      final user = await firestoreService.getUser(userId);
      return user;
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      return null;
    }
  }

  Widget _buildStatusElement() {
    final isOngoing = post.dynamicStatus == PostStatus.ongoing;

    if (isOngoing) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
        ),
        child: Text(
          'Ongoing',
          style: TextStyle(
            color: AppColors.success,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.textSecondary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          _getTimeText(post),
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }
  }

  Widget _buildPostMenu(BuildContext context) {
    return Consumer2<AuthProvider, PostProvider>(
      builder: (context, authProvider, postProvider, child) {
        final currentUserId = authProvider.currentUser?.id;
        if (currentUserId == null) return const SizedBox.shrink();

        final isAuthor = post.authorId == currentUserId;
        if (!isAuthor) return const SizedBox.shrink();

        return PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: AppColors.textSecondary, size: 14),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
          offset: const Offset(-16, 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          color: AppColors.surface,
          onSelected: (value) {
            switch (value) {
              case 'lock':
                _toggleLockPost(context, post, postProvider);
                break;
              case 'delete':
                _deletePost(context, post, postProvider);
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'lock',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    post.isLocked ? Icons.lock_open : Icons.lock,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    post.isLocked ? 'Open' : 'Close',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delete, size: 18, color: AppColors.error),
                  const SizedBox(width: 8),
                  Text(
                    'Delete',
                    style: TextStyle(color: AppColors.error, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMiddleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),

        // Location below title
        Row(
          children: [
            Icon(Icons.location_on, size: 14, color: AppColors.primary),
            const SizedBox(width: 3),
            Text(
              post.location ?? 'GSU',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Description
        Text(
          post.description!,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomRow() {
    return Row(
      children: [
        // Group member count
        Icon(Icons.people, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(
          '${post.participantIds.length} ${post.participantIds.length == 1 ? 'member' : 'members'}',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  String _getTimeText(Post post) {
    // If there's a scheduled time, show that
    if (post.scheduledTime != null) {
      final scheduledTime = post.scheduledTime!;
      final now = DateTime.now();

      // Show time in format like "2:30 PM" for today, or "Mon 2:30 PM" for other days
      if (_isSameDay(scheduledTime, now)) {
        return _formatTime(scheduledTime);
      } else if (_isWithinWeek(scheduledTime, now)) {
        return '${_formatWeekday(scheduledTime)} ${_formatTime(scheduledTime)}';
      } else {
        return '${_formatDate(scheduledTime)} ${_formatTime(scheduledTime)}';
      }
    } else {
      // Fallback to creation time if no scheduled time
      final createdTime = post.createdAt;
      final now = DateTime.now();

      if (_isSameDay(createdTime, now)) {
        return _formatTime(createdTime);
      } else if (_isWithinWeek(createdTime, now)) {
        return '${_formatWeekday(createdTime)} ${_formatTime(createdTime)}';
      } else {
        return '${_formatDate(createdTime)} ${_formatTime(createdTime)}';
      }
    }
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  bool _isWithinWeek(DateTime date, DateTime now) {
    final difference = now.difference(date).inDays.abs();
    return difference <= 7;
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour == 0
        ? 12
        : dateTime.hour > 12
        ? dateTime.hour - 12
        : dateTime.hour;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final period = dateTime.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _formatWeekday(DateTime dateTime) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[dateTime.weekday - 1];
  }

  String _formatDate(DateTime dateTime) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[dateTime.month - 1]} ${dateTime.day}';
  }

  Future<void> _toggleLockPost(
    BuildContext context,
    Post post,
    PostProvider postProvider,
  ) async {
    final isLocking = !post.isLocked;

    // Show confirmation dialog only when locking
    if (isLocking) {
      final shouldLock = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('Close Hangout?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Closing this hangout will:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.visibility_off,
                      color: AppColors.error,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Hide it from the feed for new members',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.group, color: AppColors.success, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Keep the group active for current members',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lock_open, color: AppColors.primary, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Can be opened later to make it discoverable again',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Close Hangout'),
              ),
            ],
          );
        },
      );

      if (shouldLock != true) return; // User cancelled
    }

    final String action = isLocking ? 'close' : 'open';
    final String actionPast = isLocking ? 'closed' : 'opened';

    final bool success = isLocking
        ? await postProvider.lockPost(post.id)
        : await postProvider.unlockPost(post.id);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Hangout has been $actionPast'
                : postProvider.error ?? 'Failed to $action hangout',
          ),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
    }
  }

  Future<void> _deletePost(
    BuildContext context,
    Post post,
    PostProvider postProvider,
  ) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Authentication error'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Check if author already provided feedback (from expiration prompt)
    final needsFeedback = await postProvider.doesAuthorNeedFeedbackForDeletion(
      post.id,
      currentUser.id,
    );

    if (!needsFeedback) {
      // Author already provided feedback, delete directly
      final success = await postProvider.deletePost(post.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Deleted hangout'
                  : postProvider.error ?? 'Failed to delete hangout',
            ),
            backgroundColor: success ? AppColors.success : AppColors.error,
          ),
        );
        if (success && onDeleted != null) {
          onDeleted!();
        }
      }
      return;
    }

    // Show feedback dialog for immediate author feedback
    await MeetupOutcomeDialog.show(
      context,
      onCancel: () {
        // User cancelled deletion - do nothing
      },
      onConfirmDelete: (didMeetup) async {
        // Track meetup feedback
        await AnalyticsService().trackMeetupSuccess(
          didMeetup: didMeetup,
          hangoutId: post.id,
        );

        // User confirmed deletion with feedback - proceed with deletion
        final success = await postProvider.deletePostWithFeedback(
          post.id,
          currentUser.id,
          authorDidMeetup: didMeetup,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                success
                    ? 'Deleted hangout and saved feedback'
                    : postProvider.error ?? 'Failed to delete hangout',
              ),
              backgroundColor: success ? AppColors.success : AppColors.error,
            ),
          );
          if (success && onDeleted != null) {
            onDeleted!();
          }
        }
      },
    );
  }
}
