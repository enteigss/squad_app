import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/post_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/post_model.dart';
import '../../utils/colors.dart';
import '../../widgets/custom_button.dart';

class HangoutDetailScreen extends StatelessWidget {
  final String hangoutId;

  const HangoutDetailScreen({
    super.key,
    required this.hangoutId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Hangout Details'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Consumer2<PostProvider, AuthProvider>(
        builder: (context, postProvider, authProvider, child) {
          final hangout = postProvider.getPostById(hangoutId);
          
          if (hangout == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Hangout not found',
                    style: TextStyle(
                      fontSize: 18,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'This hangout may have been deleted or the link is invalid.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          final currentUser = authProvider.currentUser;
          final isParticipant = currentUser != null && 
              hangout.participantIds.contains(currentUser.id);
          final canJoin = currentUser != null && 
              postProvider.canUserJoinPost(hangout, currentUser.id);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  hangout.title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(hangout.dynamicStatus),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    _getStatusText(hangout.dynamicStatus),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Details cards
                _buildDetailCard(
                  icon: Icons.schedule,
                  title: 'When',
                  content: _formatDateTime(hangout.scheduledTime),
                ),
                
                const SizedBox(height: 16),
                
                if (hangout.location != null) ...[
                  _buildDetailCard(
                    icon: Icons.location_on,
                    title: 'Where',
                    content: hangout.location!,
                  ),
                  const SizedBox(height: 16),
                ],
                
                _buildDetailCard(
                  icon: Icons.people,
                  title: 'Participants',
                  content: '${hangout.participantIds.length}/${hangout.maxParticipants} people',
                ),
                
                const SizedBox(height: 16),
                
                _buildDetailCard(
                  icon: Icons.person,
                  title: 'Organizer',
                  content: hangout.authorName,
                ),
                
                if (hangout.description.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Description',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      hangout.description,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
                
                const SizedBox(height: 32),
                
                // Action button
                if (isParticipant)
                  CustomButton(
                    text: 'Already Joined ✓',
                    onPressed: null,
                    width: double.infinity,
                    backgroundColor: AppColors.success,
                  )
                else if (canJoin)
                  CustomButton(
                    text: 'Join Hangout',
                    onPressed: () => _joinHangout(context, hangout, currentUser!.id),
                    width: double.infinity,
                  )
                else
                  CustomButton(
                    text: hangout.participantIds.length >= hangout.maxParticipants 
                        ? 'Hangout Full'
                        : 'Cannot Join',
                    onPressed: null,
                    width: double.infinity,
                    backgroundColor: AppColors.textSecondary,
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required String title,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  content,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(PostStatus status) {
    switch (status) {
      case PostStatus.upcoming:
        return AppColors.primary;
      case PostStatus.ongoing:
        return AppColors.success;
      case PostStatus.completed:
        return AppColors.textSecondary;
    }
  }

  String _getStatusText(PostStatus status) {
    switch (status) {
      case PostStatus.upcoming:
        return 'UPCOMING';
      case PostStatus.ongoing:
        return 'HAPPENING NOW';
      case PostStatus.completed:
        return 'COMPLETED';
    }
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'TBD';
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final selectedDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    String dateStr;
    if (selectedDate == today) {
      dateStr = 'Today';
    } else if (selectedDate == tomorrow) {
      dateStr = 'Tomorrow';
    } else {
      dateStr = '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }

    final timeStr = '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    return '$dateStr at $timeStr';
  }

  void _joinHangout(BuildContext context, Post hangout, String userId) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    try {
      final postProvider = Provider.of<PostProvider>(context, listen: false);
      final success = await postProvider.joinPost(hangout.id, userId);
      
      // Dismiss loading
      if (context.mounted) Navigator.of(context).pop();
      
      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully joined "${hangout.title}"!'),
            backgroundColor: AppColors.success,
          ),
        );
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join hangout: ${postProvider.error}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      // Dismiss loading
      if (context.mounted) Navigator.of(context).pop();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error joining hangout: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}