import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/matching_profile.dart';
import '../../providers/auth_provider.dart';
import '../../utils/colors.dart';
import '../../widgets/custom_button.dart';

class MatchingProfileEditScreen extends StatelessWidget {
  final VoidCallback onEditResponses;

  const MatchingProfileEditScreen({
    super.key,
    required this.onEditResponses,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Your Connect Profile'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          final profile = authProvider.currentUser?.matchingProfile;

          if (profile == null) {
            return const Center(
              child: Text('No matching profile found'),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Status card
                _buildStatusCard(context, profile, authProvider),
                const SizedBox(height: 24),
                // Preferences section
                _buildSectionTitle('Your Preferences'),
                const SizedBox(height: 12),
                _buildInfoCard(
                  icon: Icons.people_outline,
                  title: 'Looking to connect with',
                  value: _formatGenderPreference(profile.genderPreference),
                ),
                const SizedBox(height: 12),
                if (profile.funActivities != null &&
                    profile.funActivities!.isNotEmpty) ...[
                  _buildInfoCard(
                    icon: Icons.celebration_outlined,
                    title: 'Fun activities',
                    value: profile.funActivities!,
                  ),
                  const SizedBox(height: 12),
                ],
                if (profile.talkAboutForever != null &&
                    profile.talkAboutForever!.isNotEmpty) ...[
                  _buildInfoCard(
                    icon: Icons.chat_bubble_outline,
                    title: 'Could talk about forever',
                    value: profile.talkAboutForever!,
                  ),
                  const SizedBox(height: 12),
                ],
                // Activity ratings section
                const SizedBox(height: 24),
                _buildSectionTitle('Activity Preferences'),
                const SizedBox(height: 12),
                _buildRatingsCard(profile.activityRatings),
                if (profile.activityPreferencesElaboration != null &&
                    profile.activityPreferencesElaboration!.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    icon: Icons.edit_note,
                    title: 'More about activity preferences',
                    value: profile.activityPreferencesElaboration!,
                  ),
                ],
                // Friend type section
                if (_hasFriendTypeData(profile)) ...[
                  const SizedBox(height: 24),
                  _buildSectionTitle('Friend Style'),
                  const SizedBox(height: 12),
                  _buildFriendTypeCard(profile),
                ],
                const SizedBox(height: 32),
                // Edit button
                CustomButton(
                  text: 'Edit Responses',
                  onPressed: onEditResponses,
                  width: double.infinity,
                  isOutlined: true,
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  bool _hasFriendTypeData(MatchingProfile profile) {
    return (profile.friendType != null && profile.friendType!.isNotEmpty) ||
        (profile.friendTypeMatchWell != null && profile.friendTypeMatchWell!.isNotEmpty) ||
        (profile.friendTypeNoMatch != null && profile.friendTypeNoMatch!.isNotEmpty);
  }

  Widget _buildStatusCard(
    BuildContext context,
    MatchingProfile profile,
    AuthProvider authProvider,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: profile.isActive
            ? AppColors.success.withValues(alpha: 0.1)
            : AppColors.textSecondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: profile.isActive
              ? AppColors.success.withValues(alpha: 0.3)
              : AppColors.textSecondary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            profile.isActive ? Icons.check_circle : Icons.pause_circle_outline,
            color: profile.isActive ? AppColors.success : AppColors.textSecondary,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.isActive ? 'Active in matching pool' : 'Paused',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: profile.isActive
                        ? AppColors.success
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.isActive
                      ? 'You\'ll be included in the next matching round'
                      : 'You won\'t be matched until you activate',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: profile.isActive,
            onChanged: (value) async {
              await authProvider.toggleMatchingActive(value);
            },
            activeTrackColor: AppColors.success,
            thumbColor: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return Colors.white;
              }
              return null;
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingsCard(ActivityRatings ratings) {
    final ratingItems = [
      ('Deep conversations', ratings.deepConversations),
      ('Outdoor activities', ratings.outdoors),
      ('Just chilling', ratings.chilling),
      ('Competitive games', ratings.competitiveGames),
      ('Grabbing a meal', ratings.meals),
      ('Nights out', ratings.nightsOut),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: ratingItems.map((item) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    item.$1,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                _buildRatingDots(item.$2),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRatingDots(int rating) {
    return Row(
      children: List.generate(5, (index) {
        final isFilled = index < rating;
        return Container(
          width: 24,
          height: 24,
          margin: const EdgeInsets.only(left: 4),
          decoration: BoxDecoration(
            color: isFilled ? AppColors.primary : AppColors.divider,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isFilled ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildFriendTypeCard(MatchingProfile profile) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (profile.friendType != null && profile.friendType!.isNotEmpty) ...[
            _buildFriendTypeItem('What type of friend I am', profile.friendType!),
          ],
          if (profile.friendTypeMatchWell != null && profile.friendTypeMatchWell!.isNotEmpty) ...[
            if (profile.friendType != null && profile.friendType!.isNotEmpty)
              const SizedBox(height: 12),
            _buildFriendTypeItem('Match well with', profile.friendTypeMatchWell!),
          ],
          if (profile.friendTypeNoMatch != null && profile.friendTypeNoMatch!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _buildFriendTypeItem('Don\'t match well with', profile.friendTypeNoMatch!),
          ],
        ],
      ),
    );
  }

  Widget _buildFriendTypeItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  String _formatGenderPreference(String? preference) {
    if (preference == null || preference.isEmpty) {
      return 'Anyone';
    }
    switch (preference.toLowerCase()) {
      case 'women':
        return 'Women';
      case 'men':
        return 'Men';
      case 'anyone':
        return 'Anyone';
      default:
        return preference;
    }
  }
}
