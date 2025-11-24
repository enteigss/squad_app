import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/post_model.dart';
import '../providers/auth_provider.dart';
import '../providers/post_provider.dart';
import '../utils/colors.dart';

class PostCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onDeleted;

  const PostCard({super.key, required this.post, this.onDeleted});

  Color get _accentColor {
    switch (post.type) {
      case PostType.walking:
        return AppColors.doingGreen;
      case PostType.raising:
        return Colors.blue;
      case PostType.waving:
        return Colors.purple;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time above the card (top left, outside)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              _formatDateTime(post.scheduledTime ?? post.createdAt),
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Card content
          Container(
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.divider, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: IntrinsicHeight(
                child: Row(
                  children: [
                    // Left accent strip
                    Container(
                      width: 4,
                      decoration: BoxDecoration(
                        color: _accentColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                        ),
                      ),
                    ),
                    // Main content
                    Expanded(
                      child: Stack(
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _handleTap(context),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Header row (not shown for waving)
                                    if (post.type != PostType.waving) ...[
                                      _buildHeader(),
                                      const SizedBox(height: 12),
                                    ],
                                    // Main content
                                    _buildBody(),

                                    // Description (if provided)
                                    if (post.description != null && post.description!.isNotEmpty) ...[
                                      const SizedBox(height: 8),
                                      Text(
                                        post.description!,
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 13,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],

                                    const SizedBox(height: 0),
                                    // Bottom row: member count (left) and tap to view (right)
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        // Member count (bottom left)
                                        Transform.translate(
                                          offset: const Offset(4, 4),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                Icons.people,
                                                color: AppColors.textHint,
                                                size: 14,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${post.participantIds.length}',
                                                style: TextStyle(
                                                  color: AppColors.textHint,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w400,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Tap to view hint (bottom right)
                                        Transform.translate(
                                          offset: const Offset(4, 4),
                                          child: Text(
                                            'Tap to view ›',
                                            style: TextStyle(
                                              color: AppColors.textHint,
                                              fontSize: 11,
                                              fontWeight: FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Menu button (only for author)
                          _buildMenuButton(context),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleTap(BuildContext context) {
    context.push('/group-members/${post.id}');
  }

  Widget _buildMenuButton(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.id;

    // Only show menu button if current user is the author
    if (currentUserId != post.authorId) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 4,
      right: 4,
      child: PopupMenuButton<String>(
        icon: Icon(
          Icons.more_vert,
          color: AppColors.textSecondary,
          size: 20,
        ),
        padding: EdgeInsets.zero,
        onSelected: (value) {
          if (value == 'lock') {
            _toggleLock(context);
          } else if (value == 'delete') {
            _confirmDelete(context);
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'lock',
            child: Row(
              children: [
                Icon(
                  post.isLocked ? Icons.lock_open : Icons.lock,
                  size: 20,
                  color: AppColors.textPrimary,
                ),
                const SizedBox(width: 12),
                Text(post.isLocked ? 'Unlock Post' : 'Lock Post'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                const Icon(Icons.delete, size: 20, color: Colors.red),
                const SizedBox(width: 12),
                const Text('Delete Post', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toggleLock(BuildContext context) async {
    final postProvider = Provider.of<PostProvider>(context, listen: false);
    final bool success;

    if (post.isLocked) {
      success = await postProvider.unlockPost(post.id);
    } else {
      success = await postProvider.lockPost(post.id);
    }

    if (context.mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              post.isLocked
                  ? 'Post locked. No new members can join.'
                  : 'Post unlocked. New members can join.',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update post'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Post'),
        content: const Text('Are you sure you want to delete this post? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deletePost(context);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _deletePost(BuildContext context) async {
    final postProvider = Provider.of<PostProvider>(context, listen: false);
    final success = await postProvider.deletePost(post.id);

    if (context.mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Post deleted'),
            backgroundColor: AppColors.success,
          ),
        );
        onDeleted?.call();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete post'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String _formatAuthorName() {
    final name = post.authorName;

    // Convert class year to graduation year or label
    String? yearDisplay;
    if (post.authorYear != null) {
      final classYear = post.authorYear!.toLowerCase();
      switch (classYear) {
        case 'freshman':
          yearDisplay = '\'29';
          break;
        case 'sophomore':
          yearDisplay = '\'28';
          break;
        case 'junior':
          yearDisplay = '\'27';
          break;
        case 'senior':
          yearDisplay = '\'26';
          break;
        case 'graduate':
          yearDisplay = 'Grad';
          break;
        default:
          // If already a year number, extract last 2 digits
          final yearShort = post.authorYear!.length >= 2
              ? post.authorYear!.substring(post.authorYear!.length - 2)
              : post.authorYear;
          yearDisplay = '\'$yearShort';
      }
    }

    if (post.authorDorm != null && yearDisplay != null) {
      return '$name (${post.authorDorm}, $yearDisplay)';
    } else if (post.authorDorm != null) {
      return '$name (${post.authorDorm})';
    } else if (yearDisplay != null) {
      return '$name ($yearDisplay)';
    }
    return name;
  }

  Widget _buildHeader() {
    String emoji;
    String text;

    switch (post.type) {
      case PostType.walking:
        emoji = '🚶';
        text = '${_formatAuthorName()} is...';
        break;
      case PostType.raising:
        emoji = '🙋';
        text = '${_formatAuthorName()} wants to...';
        break;
      case PostType.waving:
        // Waving doesn't have a header
        return const SizedBox.shrink();
    }

    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 6),
        Text(
          text,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildBody() {
    // Waving type just shows "[Name] is free"
    if (post.type == PostType.waving) {
      return Text(
        '👋 ${_formatAuthorName()} is free',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    // Walking and Raising show activity + location
    final activityText = _buildActivityText();
    final emoji = _getActivityEmoji();

    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            activityText,
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  String _buildActivityText() {
    // Handle custom activity
    if (post.activity == Activity.other && post.customActivity != null) {
      return post.customActivity!;
    }

    // Get activity name
    final activityName = _getActivityName();

    // Handle walking with from/to locations
    if (post.activity == Activity.walking) {
      if (post.location != null && post.locationTo != null) {
        return '$activityName from ${post.location} to ${post.locationTo}';
      } else if (post.location != null) {
        return '$activityName from ${post.location}';
      } else if (post.locationTo != null) {
        return '$activityName to ${post.locationTo}';
      }
      return activityName;
    }

    // Handle other activities with location
    if (post.location != null) {
      return '$activityName at ${post.location}';
    }

    return activityName;
  }

  String _getActivityName() {
    switch (post.activity) {
      case Activity.diningHall:
        return 'Eating';
      case Activity.studying:
        return 'Studying';
      case Activity.chilling:
        return 'Chilling';
      case Activity.walking:
        return 'Walking';
      case Activity.fitRec:
        return 'Working out';
      case Activity.other:
        return post.customActivity ?? 'Doing something';
      case null:
        return 'Doing something';
    }
  }

  String _getActivityEmoji() {
    switch (post.activity) {
      case Activity.diningHall:
        return '🍔';
      case Activity.studying:
        return '📚';
      case Activity.chilling:
        return '😎';
      case Activity.walking:
        return '🚶';
      case Activity.fitRec:
        return '💪';
      case Activity.other:
        return '✨';
      case null:
        return '📍';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(dateTime.year, dateTime.month, dateTime.day);

    // If today, just show time
    if (dateOnly == today) {
      return _formatTime(dateTime);
    }

    final dayPart = _formatDay(dateTime);
    final timePart = _formatTime(dateTime);
    return '$dayPart, $timePart';
  }

  String _formatDay(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dateOnly = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (dateOnly == tomorrow) {
      return 'Tomorrow';
    } else if (dateOnly.isAfter(today) &&
        dateOnly.isBefore(today.add(const Duration(days: 7)))) {
      // Within the next week - show day of week
      const weekdays = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      return weekdays[dateTime.weekday - 1];
    } else {
      // More than a week away - show date
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
}
