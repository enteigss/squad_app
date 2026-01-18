import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/user_model.dart';
import '../../models/report_model.dart';
import '../../services/report_service.dart';
import '../../services/block_service.dart';
import '../../utils/colors.dart';
import '../../widgets/report_dialog.dart';
import '../../widgets/block_confirmation_dialog.dart';
import '../../widgets/profile_avatar.dart';
import '../../providers/post_provider.dart';
import '../../providers/chat_provider.dart';

class ProfileDetailScreen extends StatefulWidget {
  final UserModel? user;

  const ProfileDetailScreen({super.key, this.user});

  @override
  State<ProfileDetailScreen> createState() => _ProfileDetailScreenState();
}

class _ProfileDetailScreenState extends State<ProfileDetailScreen> {
  final BlockService _blockService = BlockService();
  bool _isBlocked = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkBlockStatus();
  }

  Future<void> _checkBlockStatus() async {
    if (widget.user == null) return;

    final isBlocked = await _blockService.isBlocked(widget.user!.id);
    if (mounted) {
      setState(() {
        _isBlocked = isBlocked;
      });
    }
  }

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
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Block Button
                    IconButton(
                      icon: Icon(_isBlocked ? Icons.person_add : Icons.block),
                      onPressed: _isLoading
                          ? null
                          : () => _toggleBlockUser(authProvider),
                      tooltip: _isBlocked ? 'Unblock User' : 'Block User',
                    ),
                    // Report Button
                    IconButton(
                      icon: const Icon(Icons.flag_outlined),
                      onPressed: () => _showReportDialog(context, authProvider),
                      tooltip: 'Report User',
                    ),
                  ],
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          final UserModel? currentUser =
              widget.user ?? authProvider.currentUser;

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
              ProfileAvatar(
                imageUrl: user.photoUrl,
                name: user.displayName ?? user.username,
                radius: 50,
                backgroundColor: Colors.white,
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

          // Class Year
          if (user.classYear != null)
            _buildInfoRow(
              context,
              icon: Icons.school_outlined,
              label: 'Class Year',
              value: user.classYear!,
            ),

          if (user.classYear != null) const SizedBox(height: 12),

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

    // Don't show report button if viewing own profile (widget.user is null = own profile)
    if (widget.user == null) return false;

    // Don't show report button if viewing own profile (widget.user matches current user)
    if (widget.user!.id == currentUser.id) return false;

    // Show report button when viewing another user's profile
    return true;
  }

  // Show report dialog
  Future<void> _showReportDialog(
    BuildContext context,
    AuthProvider authProvider,
  ) async {
    final currentUser = authProvider.currentUser;

    if (currentUser == null || widget.user == null) {
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
        contentId: widget.user!.id,
        authorId: widget.user!.id, // Same as contentId for user reports
        contentSnippet: ReportService.createUserContentSnippet(
          displayName: widget.user!.displayName ?? widget.user!.username,
          bio: widget.user!.bio,
          location: widget.user!.location,
          interests: widget.user!.interests,
        ),
        onSubmit: (ReportReason reason) =>
            _submitReport(context, reason, currentUser),
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
  Future<void> _submitReport(
    BuildContext context,
    ReportReason reason,
    UserModel currentUser,
  ) async {
    if (widget.user == null) return;

    final reportService = ReportService();

    try {
      await reportService.submitReport(
        contentType: 'user',
        contentId: widget.user!.id,
        contentTitle: widget.user!.displayName ?? widget.user!.username,
        authorId: widget.user!.id, // Same as contentId for user reports
        contentSnippet: ReportService.createUserContentSnippet(
          displayName: widget.user!.displayName ?? widget.user!.username,
          bio: widget.user!.bio,
          location: widget.user!.location,
          interests: widget.user!.interests,
        ),
        reason: reason,
        reporterUid: currentUser.id,
        reporterDisplayName: currentUser.displayName ?? 'Unknown User',
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Report submitted successfully. Thank you for helping keep our community safe.',
            ),
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

  // Toggle block/unblock user
  Future<void> _toggleBlockUser(AuthProvider authProvider) async {
    if (widget.user == null) return;

    // If unblocking, proceed directly
    if (_isBlocked) {
      setState(() {
        _isLoading = true;
      });

      try {
        await _blockService.unblockUser(widget.user!.id);

        // Update providers with modified user data
        if (mounted) {
          final currentUser = authProvider.currentUser;
          if (currentUser != null) {
            final updatedBlockedIds = List<String>.from(
              currentUser.blockedUserIds,
            )..remove(widget.user!.id);
            final updatedUser = currentUser.copyWith(
              blockedUserIds: updatedBlockedIds,
            );

            Provider.of<PostProvider>(
              context,
              listen: false,
              // ignore: deprecated_member_use_from_same_package
            ).setCurrentUser(updatedUser);
            Provider.of<ChatProvider>(
              context,
              listen: false,
              // ignore: deprecated_member_use_from_same_package
            ).setCurrentUser(updatedUser);
          }
        }

        if (mounted) {
          setState(() {
            _isBlocked = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Unblocked ${widget.user!.displayName ?? widget.user!.username}',
              ),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error unblocking user: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
      return;
    }

    // If blocking, show confirmation dialog first
    final userName = widget.user!.displayName ?? widget.user!.username;
    final confirmed = await BlockConfirmationDialog.show(context, userName);

    if (confirmed == true) {
      setState(() {
        _isLoading = true;
      });

      try {
        await _blockService.blockUser(widget.user!.id);

        // Update providers with modified user data
        if (mounted) {
          final currentUser = authProvider.currentUser;
          if (currentUser != null) {
            final updatedBlockedIds = List<String>.from(
              currentUser.blockedUserIds,
            )..add(widget.user!.id);
            final updatedUser = currentUser.copyWith(
              blockedUserIds: updatedBlockedIds,
            );

            Provider.of<PostProvider>(
              context,
              listen: false,
              // ignore: deprecated_member_use_from_same_package
            ).setCurrentUser(updatedUser);
            Provider.of<ChatProvider>(
              context,
              listen: false,
              // ignore: deprecated_member_use_from_same_package
            ).setCurrentUser(updatedUser);
          }
        }

        if (mounted) {
          setState(() {
            _isBlocked = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Blocked ${widget.user!.displayName ?? widget.user!.username}',
              ),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error blocking user: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }
}
