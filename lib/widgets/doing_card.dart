import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/post_model.dart';
import '../utils/colors.dart';

class DoingCard extends StatelessWidget {
  final Post post;
  final VoidCallback? onDeleted;

  const DoingCard({super.key, required this.post, this.onDeleted});

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
                    // Left accent strip for "Doing" type
                    Container(
                      width: 4,
                      decoration: BoxDecoration(
                        color: AppColors.doingGreen,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                        ),
                      ),
                    ),
                    // Main content
                    Expanded(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _handleTap(context),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header row
                                _buildHeader(),
                                const SizedBox(height: 12),
                                // Main content
                                _buildBody(),
                                const SizedBox(height: 0),
                                // Tap to view hint
                                Transform.translate(
                                  offset: const Offset(4, 4),
                                  child: Align(
                                    alignment: Alignment.bottomRight,
                                    child: Text(
                                      'Tap to view ›',
                                      style: TextStyle(
                                        color: AppColors.textHint,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
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

  Widget _buildHeader() {
    return Row(
      children: [
        const Text('🚶', style: TextStyle(fontSize: 14)),
        const SizedBox(width: 6),
        Text(
          '${post.authorName} is...',
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
