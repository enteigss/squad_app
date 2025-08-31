import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../models/report_model.dart';
import '../../services/report_service.dart';
import '../../utils/colors.dart';
import '../../widgets/report_dialog.dart';

class ProfileDetailScreen extends StatelessWidget {
  final UserModel? user;

  const ProfileDetailScreen({super.key, this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile Details'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        elevation: 0,
        actions: [
          Consumer<AuthProvider>(
            builder: (context, authProvider, child) {
              if (_canShowReportButton(context, authProvider)) {
                return IconButton(
                  icon: const Icon(Icons.flag_outlined),
                  onPressed: () => _showReportDialog(context, authProvider),
                  tooltip: 'Report User',
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          final UserModel? currentUser = user ?? authProvider.currentUser;

          if (currentUser == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.person_off,
                    size: 64,
                    color: AppColors.textSecondary,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No profile data available',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            );
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                // Profile Header Section
                _buildProfileHeader(context, currentUser),

                // Profile Info Cards
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Basic Info Card
                      _buildBasicInfoCard(context, currentUser),

                      const SizedBox(height: 16),

                      // About Section Card
                      if (currentUser.bio != null &&
                          currentUser.bio!.isNotEmpty)
                        _buildAboutCard(context, currentUser),

                      if (currentUser.bio != null &&
                          currentUser.bio!.isNotEmpty)
                        const SizedBox(height: 16),

                      // Interests Card
                      if (currentUser.interests.isNotEmpty)
                        _buildInterestsCard(context, currentUser),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, UserModel user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // Profile Picture
          Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.white,
                child: user.photoUrl != null
                    ? ClipOval(
                        child: Image.network(
                          user.photoUrl!,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildDefaultAvatar(user);
                          },
                        ),
                      )
                    : _buildDefaultAvatar(user),
              ),

              // Online Status Indicator
              Positioned(
                bottom: 4,
                right: 4,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: user.isOnline
                        ? AppColors.onlineIndicator
                        : AppColors.offlineIndicator,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Name
          Text(
            user.displayName ?? user.username,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 4),

          // Username
          if (user.displayName != null && user.displayName != user.username)
            Text(
              '@${user.username}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),

          const SizedBox(height: 8),

          // Status
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              user.isOnline ? 'Online' : 'Offline',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar(UserModel user) {
    final String initials =
        user.displayName != null && user.displayName!.isNotEmpty
        ? user.displayName!.split(' ').map((n) => n[0]).join().toUpperCase()
        : user.username[0].toUpperCase();

    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: AppColors.getAvatarColor(user.displayName ?? user.username),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoCard(BuildContext context, UserModel user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.primary, size: 24),
              const SizedBox(width: 12),
              Text(
                'Basic Information',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Email
          _buildInfoRow(
            context,
            icon: Icons.email_outlined,
            label: 'Email',
            value: user.email,
          ),

          const SizedBox(height: 12),

          // Age
          if (user.age != null)
            _buildInfoRow(
              context,
              icon: Icons.cake_outlined,
              label: 'Age',
              value: '${user.age} years old',
            ),

          if (user.age != null) const SizedBox(height: 12),

          // Location
          if (user.location != null && user.location!.isNotEmpty)
            _buildInfoRow(
              context,
              icon: Icons.location_on_outlined,
              label: 'Location',
              value: user.location!,
            ),

          if (user.location != null && user.location!.isNotEmpty)
            const SizedBox(height: 12),

          // Member Since
          _buildInfoRow(
            context,
            icon: Icons.calendar_today_outlined,
            label: 'Member Since',
            value: _formatDate(user.createdAt),
          ),

          const SizedBox(height: 12),

          // Last Seen
          if (user.lastSeen != null)
            _buildInfoRow(
              context,
              icon: Icons.access_time_outlined,
              label: 'Last Seen',
              value: _formatLastSeen(user.lastSeen!),
            ),
        ],
      ),
    );
  }

  Widget _buildAboutCard(BuildContext context, UserModel user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_outline, color: AppColors.primary, size: 24),
              const SizedBox(width: 12),
              Text(
                'About Me',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Text(
            user.bio!,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInterestsCard(BuildContext context, UserModel user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite_outline, color: AppColors.primary, size: 24),
              const SizedBox(width: 12),
              Text(
                'Interests (${user.interests.length})',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: user.interests.map((interest) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  interest,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondary),
        const SizedBox(width: 12),
        Text(
          '$label:',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatLastSeen(DateTime lastSeen) {
    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minutes ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return _formatDate(lastSeen);
    }
  }

  // Check if current user can see the report button
  bool _canShowReportButton(BuildContext context, AuthProvider authProvider) {
    final currentUser = authProvider.currentUser;
    
    // Don't show report button if not authenticated
    if (currentUser == null) return false;
    
    // Don't show report button if viewing own profile (user is null = own profile)
    if (user == null) return false;
    
    // Don't show report button if viewing own profile (user matches current user)
    if (user!.id == currentUser.id) return false;
    
    // Show report button when viewing another user's profile
    return true;
  }

  // Show report dialog
  Future<void> _showReportDialog(BuildContext context, AuthProvider authProvider) async {
    final currentUser = authProvider.currentUser;
    
    if (currentUser == null || user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to report user at this time'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      await ReportDialog.show(
        context,
        contentType: 'user',
        contentId: user!.id,
        contentTitle: user!.displayName ?? user!.username,
        authorId: user!.id, // Same as contentId for user reports
        contentSnippet: ReportService.createUserContentSnippet(
          displayName: user!.displayName ?? user!.username,
          bio: user!.bio,
          location: user!.location,
          interests: user!.interests,
        ),
        onSubmit: (ReportReason reason) => _submitReport(context, reason, currentUser),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error showing report dialog: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // Submit report
  Future<void> _submitReport(BuildContext context, ReportReason reason, UserModel currentUser) async {
    if (user == null) return;

    final reportService = ReportService();

    try {
      await reportService.submitReport(
        contentType: 'user',
        contentId: user!.id,
        contentTitle: user!.displayName ?? user!.username,
        authorId: user!.id, // Same as contentId for user reports
        contentSnippet: ReportService.createUserContentSnippet(
          displayName: user!.displayName ?? user!.username,
          bio: user!.bio,
          location: user!.location,
          interests: user!.interests,
        ),
        reason: reason,
        reporterUid: currentUser.id,
        reporterDisplayName: currentUser.displayName ?? 'Unknown User',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report submitted successfully. Thank you for helping keep our community safe.'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit report: $e'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}
