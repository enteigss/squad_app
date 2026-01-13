import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/post_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/post_model.dart';
import '../../services/analytics_service.dart';
import '../../services/navigation_service.dart';
import '../../utils/colors.dart';
import '../../widgets/custom_button.dart';

class HangoutInvitationScreen extends StatelessWidget {
  final String hangoutId;

  const HangoutInvitationScreen({super.key, required this.hangoutId});

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
          final currentUser = authProvider.currentUser;

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
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              ),
            );
          }

          final isParticipant =
              currentUser != null &&
              hangout.participantIds.contains(currentUser.id);
          final canJoin =
              currentUser != null &&
              postProvider.canUserJoinPost(
                hangout,
                currentUser.id,
                userGender: currentUser.gender,
              );

          // Determine why user can't join for better error messaging
          String? cantJoinReason;
          String? cantJoinExplanation;
          if (currentUser != null && !isParticipant && !canJoin) {
            final effectiveLimit = hangout.maxParticipants ?? 100;
            if (hangout.participantIds.length >= effectiveLimit) {
              cantJoinReason = 'Hangout Full';
              cantJoinExplanation =
                  'This hangout has reached its maximum number of participants.';
            } else if (hangout.dynamicStatus == PostStatus.completed) {
              cantJoinReason = 'Already Completed';
              cantJoinExplanation = 'This hangout has already ended.';
            } else {
              cantJoinReason = 'Cannot Join';
              cantJoinExplanation =
                  'This hangout has gender preferences set by the organizer that don\'t match your profile.';
            }
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(
                  'Invitation',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 16),

                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
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
                  content: hangout.maxParticipants != null
                      ? '${hangout.participantIds.length}/${hangout.maxParticipants} people'
                      : '${hangout.participantIds.length} people',
                ),

                const SizedBox(height: 16),

                _buildDetailCard(
                  icon: Icons.person,
                  title: 'Organizer',
                  content: hangout.authorName,
                ),

                if (hangout.description != null &&
                    hangout.description!.isNotEmpty) ...[
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
                      hangout.description!,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 32),

                // Action buttons
                if (isParticipant)
                  Column(
                    children: [
                      CustomButton(
                        text: 'Already Joined ✓',
                        onPressed: null,
                        width: double.infinity,
                        backgroundColor: AppColors.success,
                      ),
                      const SizedBox(height: 12),
                      CustomButton(
                        text: 'Go Back to Plans',
                        onPressed: () => NavigationService.goToPath('/plans'),
                        width: double.infinity,
                        backgroundColor: AppColors.surface,
                        textColor: AppColors.textPrimary,
                      ),
                    ],
                  )
                else if (canJoin)
                  Column(
                    children: [
                      CustomButton(
                        text: 'Join Hangout',
                        onPressed: () =>
                            _joinHangout(context, hangout, currentUser.id),
                        width: double.infinity,
                      ),
                      const SizedBox(height: 12),
                      CustomButton(
                        text: 'Not Right Now',
                        onPressed: () => _notRightNow(context),
                        width: double.infinity,
                        backgroundColor: AppColors.surface,
                        textColor: AppColors.textPrimary,
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      CustomButton(
                        text: cantJoinReason ?? 'Cannot Join',
                        onPressed: null,
                        width: double.infinity,
                        backgroundColor: AppColors.textSecondary,
                      ),
                      if (cantJoinExplanation != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  cantJoinExplanation,
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontSize: 14,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      CustomButton(
                        text: 'Go Back to Plans',
                        onPressed: () => NavigationService.goToPath('/plans'),
                        width: double.infinity,
                        backgroundColor: AppColors.surface,
                        textColor: AppColors.textPrimary,
                      ),
                    ],
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
            color: Colors.black.withValues(alpha: 0.05),
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
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
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

    final timeStr =
        '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    return '$dateStr at $timeStr';
  }

  void _joinHangout(BuildContext context, Post hangout, String userId) async {
    debugPrint('🚀 JOIN HANGOUT FLOW - Starting join process');
    debugPrint('📋 Hangout ID: ${hangout.id}');
    debugPrint('📋 User ID: $userId');
    debugPrint(
      '📋 Current Participants: ${hangout.participantIds.length}/${hangout.maxParticipants}',
    );

    // Show loading
    debugPrint('⏳ Showing loading dialog');
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    try {
      debugPrint('🔄 Getting PostProvider instance');
      final postProvider = Provider.of<PostProvider>(context, listen: false);

      debugPrint('📞 Calling postProvider.joinPost()');
      final success = await postProvider.joinPost(hangout.id, userId);
      debugPrint('✅ joinPost() completed with success: $success');

      // Track hangout join attempt
      if (success) {
        debugPrint(
          '📊 HANGOUT INVITATION SCREEN - Tracking hangout join analytics',
        );
        debugPrint('📋 User ID: $userId');
        debugPrint('📋 Hangout ID: ${hangout.id}');

        await AnalyticsService().trackHangoutJoined(
          userId: userId,
          hangoutId: hangout.id,
        );

        debugPrint(
          '✅ HANGOUT INVITATION SCREEN - Analytics tracking completed',
        );
      }

      // Dismiss loading
      debugPrint('❌ Dismissing loading dialog');
      if (context.mounted) {
        Navigator.of(context).pop();
        debugPrint('✅ Loading dialog dismissed');
      } else {
        debugPrint('⚠️  Context not mounted, could not dismiss loading dialog');
      }

      if (success && context.mounted) {
        debugPrint('🎉 Join was successful! Proceeding to navigation');

        // Navigate to plans tab after successful join
        debugPrint('🧭 Preparing to navigate to plans tab');
        debugPrint('🔗 Target route: /plans');

        // Navigate immediately to show user their joined hangout
        debugPrint('🚀 Attempting navigation to plans tab');
        debugPrint('📍 Calling NavigationService.goToPath("/plans")');

        try {
          NavigationService.goToPath('/plans');
          debugPrint('✅ Navigation call completed successfully');
        } catch (e) {
          debugPrint('💥 ERROR during navigation: $e');
          debugPrint('🔍 Error type: ${e.runtimeType}');
        }
      } else if (context.mounted) {
        debugPrint('❌ Join failed! Showing error snackbar');
        debugPrint('🔍 PostProvider error: ${postProvider.error}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join hangout: ${postProvider.error}'),
            backgroundColor: AppColors.error,
          ),
        );
      } else {
        debugPrint('⚠️  Join failed and context not mounted');
      }
    } catch (e) {
      debugPrint('💥 EXCEPTION in _joinHangout: $e');
      debugPrint('🔍 Exception type: ${e.runtimeType}');
      debugPrint('📚 Stack trace: ${StackTrace.current}');

      // Dismiss loading
      debugPrint('❌ Dismissing loading dialog due to exception');
      if (context.mounted) {
        Navigator.of(context).pop();
        debugPrint('✅ Loading dialog dismissed after exception');
      } else {
        debugPrint(
          '⚠️  Context not mounted, could not dismiss loading dialog after exception',
        );
      }

      if (context.mounted) {
        debugPrint('🚨 Showing exception error snackbar');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error joining hangout: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      } else {
        debugPrint(
          '⚠️  Context not mounted, could not show exception error snackbar',
        );
      }
    }

    debugPrint('🏁 JOIN HANGOUT FLOW - Method completed');
  }

  void _notRightNow(BuildContext context) {
    debugPrint('👋 NOT RIGHT NOW - User declined to join hangout');

    // Navigate back to home tab
    debugPrint('🧭 Navigating back to home tab');

    try {
      NavigationService.goToPath('/home');
      debugPrint('✅ Navigation to home completed successfully');
    } catch (e) {
      debugPrint('💥 ERROR during navigation: $e');
      debugPrint('🔍 Error type: ${e.runtimeType}');

      // Fallback: just pop the current screen
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }
}
