import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../providers/auth_provider.dart';
import '../../providers/post_provider.dart';
import '../../utils/colors.dart';
import '../../utils/url_launcher_helper.dart';
import '../../services/block_service.dart';
import '../../services/notification_service.dart';
import '../../services/analytics_service.dart';
import '../../services/feedback_service.dart';
import '../../models/user_model.dart';
import '../../widgets/profile_avatar.dart';
import 'edit_profile_screen.dart';
import 'analytics_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final NotificationService _notificationService = NotificationService();
  bool _notificationsEnabled = false;
  bool _analyticsEnabled = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkNotificationStatus();
    _checkAnalyticsStatus();
  }

  Future<void> _checkNotificationStatus() async {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user != null) {
      setState(() {
        _notificationsEnabled = user.subscribedTopics.isNotEmpty;
      });
    }
  }

  Future<void> _checkAnalyticsStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hasConsent = prefs.getBool('analytics_consent') ?? false;
      setState(() {
        _analyticsEnabled = hasConsent;
      });
    } catch (e) {
      debugPrint('Error checking analytics status: $e');
    }
  }

  Future<void> _toggleAnalytics(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('analytics_consent', enabled);

      if (enabled) {
        AnalyticsService().initialize();
        debugPrint('✅ Analytics enabled by user');
      } else {
        AnalyticsService().disable();
        debugPrint('📊 Analytics disabled by user');
      }

      setState(() {
        _analyticsEnabled = enabled;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              enabled
                  ? 'Analytics enabled - helps us improve the app'
                  : 'Analytics disabled - no data will be collected',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error toggling analytics: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update analytics preference'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // DEBUG ONLY: Create test feedback prompts
  Future<void> _createTestFeedbackPrompts(String userId) async {
    if (kDebugMode) {
      try {
        final feedbackService = FeedbackService();
        await feedbackService.createTestFeedbackPrompts(userId);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Test feedback prompts created! Restart the app to see them.',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        debugPrint('Failed to create test feedback prompts: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to create test feedback prompts'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _showSignOutDialog,
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          final user = authProvider.currentUser;

          if (user == null) {
            return const Center(child: CircularProgressIndicator());
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Profile Picture
                ProfileAvatar(
                  imageUrl: user.photoUrl,
                  name: user.displayName ?? user.username,
                  radius: 40,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  textColor: AppColors.primary,
                ),

                const SizedBox(height: 16),

                // User Name
                Text(
                  user.displayName ?? user.username,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),

                const SizedBox(height: 6),

                // Username
                Text(
                  '@${user.username}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),

                const SizedBox(height: 20),

                // Profile Info Cards
                _buildInfoCard('Email', user.email),
                if (user.bio != null) _buildInfoCard('Bio', user.bio!),
                if (user.location != null)
                  _buildInfoCard('Location', user.location!),
                if (user.classYear != null)
                  _buildInfoCard('Class Year', user.classYear!),

                const SizedBox(height: 16),

                // Interests
                if (user.interests.isNotEmpty)
                  _buildInterestsSection(user.interests),

                const SizedBox(height: 20),

                // Edit Profile Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _editProfile,
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('Edit Profile'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),

                // DEBUG ONLY: Test Feedback Prompts Button
                if (kDebugMode) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _createTestFeedbackPrompts(user.id),
                      icon: const Icon(Icons.bug_report, size: 18),
                      label: const Text('Create Test Feedback Prompts'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Notifications Toggle
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.notifications,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Notifications',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Receive notifications for new hangouts',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _isLoading
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.primary,
                                ),
                              ),
                            )
                          : Switch(
                              value: _notificationsEnabled,
                              onChanged: _toggleNotifications,
                              activeThumbColor: AppColors.primary,
                            ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Contact & Feedback Section
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showContactInfo,
                    icon: const Icon(Icons.feedback, size: 18),
                    label: const Text('Contact & Feedback'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(
                        color: AppColors.divider.withValues(alpha: 0.3),
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Legal & Privacy Section
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showLegalOptions,
                    icon: const Icon(Icons.privacy_tip, size: 18),
                    label: const Text('Legal & Privacy'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(
                        color: AppColors.divider.withValues(alpha: 0.3),
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Blocked Users Section
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showBlockedUsers,
                    icon: const Icon(Icons.block, size: 18),
                    label: const Text('Blocked Users'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      foregroundColor: AppColors.textPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(
                        color: AppColors.divider.withValues(alpha: 0.3),
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),

                // Analytics Button (Debug only)
                if (kDebugMode) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _viewAnalytics,
                      icon: const Icon(Icons.analytics, size: 18),
                      label: const Text('View Analytics (Debug)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.textSecondary.withValues(
                          alpha: 0.1,
                        ),
                        foregroundColor: AppColors.textSecondary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: BorderSide(
                          color: AppColors.textSecondary.withValues(alpha: 0.3),
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 20),

                // Delete Account Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showDeleteAccountDialog,
                    icon: const Icon(Icons.delete_forever, size: 18),
                    label: const Text('Delete Account'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(String label, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildInterestsSection(List<String> interests) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Interests',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: interests
                .map(
                  (interest) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      interest,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  void _editProfile() {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user != null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => EditProfileScreen(user: user)),
      );
    }
  }

  void _viewAnalytics() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AnalyticsScreen()),
    );
  }

  void _showContactInfo() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            'Contact & Feedback',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Have feedback or need to report something? We\'d love to hear from you!',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Text(
                'Contact us at:',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SelectableText(
                'jordan@linkupbu.com',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Close', style: TextStyle(color: AppColors.primary)),
            ),
          ],
        );
      },
    );
  }

  void _showLegalOptions() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface,
              title: Text(
                'Legal & Privacy',
                style: TextStyle(color: AppColors.textPrimary),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: Icon(Icons.analytics, color: AppColors.primary),
                    title: Text(
                      'Analytics Data',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                    subtitle: Text(
                      'Help improve the app with anonymous usage data',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                    trailing: Switch(
                      value: _analyticsEnabled,
                      onChanged: (value) async {
                        await _toggleAnalytics(value);
                        setDialogState(() {}); // Update dialog UI immediately
                      },
                      activeThumbColor: AppColors.primary,
                    ),
                  ),
                  ListTile(
                    leading: Icon(Icons.privacy_tip, color: AppColors.primary),
                    title: Text(
                      'Privacy Policy',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                    trailing: Icon(
                      Icons.open_in_browser,
                      color: AppColors.textSecondary,
                    ),
                    onTap: () async {
                      Navigator.of(context).pop();
                      final success =
                          await UrlLauncherHelper.launchPrivacyPolicy();
                      if (!success && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Could not open privacy policy'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    },
                  ),
                  ListTile(
                    leading: Icon(
                      Icons.delete_outline,
                      color: AppColors.primary,
                    ),
                    title: Text(
                      'Data Deletion',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                    trailing: Icon(
                      Icons.open_in_browser,
                      color: AppColors.textSecondary,
                    ),
                    onTap: () async {
                      Navigator.of(context).pop();
                      final success =
                          await UrlLauncherHelper.launchDataDeletion();
                      if (!success && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Could not open data deletion page'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.shield, color: AppColors.primary),
                    title: Text(
                      'Child Safety',
                      style: TextStyle(color: AppColors.textPrimary),
                    ),
                    trailing: Icon(
                      Icons.open_in_browser,
                      color: AppColors.textSecondary,
                    ),
                    onTap: () async {
                      Navigator.of(context).pop();
                      final success =
                          await UrlLauncherHelper.launchChildSafety();
                      if (!success && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Could not open child safety page'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'Close',
                    style: TextStyle(color: AppColors.primary),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            'Sign Out',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: Text(
            'Are you sure you want to sign out?',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _signOut();
              },
              child: Text('Sign Out', style: TextStyle(color: AppColors.error)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _signOut() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final postProvider = Provider.of<PostProvider>(context, listen: false);

      // Clean up PostProvider subscriptions before signing out
      postProvider.cleanup();

      await authProvider.signOut();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully signed out'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to sign out: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showBlockedUsers() async {
    final blockService = BlockService();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            'Blocked Users',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: FutureBuilder<List<UserModel>>(
            future: blockService.getBlockedUsers(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return SizedBox(
                  height: 100,
                  child: Center(
                    child: Text(
                      'Error loading blocked users',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                );
              }

              final blockedUsers = snapshot.data ?? [];

              if (blockedUsers.isEmpty) {
                return SizedBox(
                  height: 100,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.block,
                          size: 32,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No blocked users',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return SizedBox(
                width: double.maxFinite,
                height: 300,
                child: ListView.builder(
                  itemCount: blockedUsers.length,
                  itemBuilder: (context, index) {
                    final user = blockedUsers[index];
                    return ListTile(
                      leading: ProfileAvatar(
                        imageUrl: user.photoUrl,
                        name: user.displayName ?? user.username,
                        radius: 20,
                        backgroundColor: AppColors.primary.withValues(
                          alpha: 0.1,
                        ),
                        textColor: AppColors.primary,
                      ),
                      title: Text(
                        user.displayName ?? user.username,
                        style: TextStyle(color: AppColors.textPrimary),
                      ),
                      subtitle: Text(
                        '@${user.username}',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                      trailing: TextButton(
                        onPressed: () => _unblockUser(user),
                        child: Text(
                          'Unblock',
                          style: TextStyle(color: AppColors.primary),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Close', style: TextStyle(color: AppColors.primary)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _unblockUser(UserModel user) async {
    final blockService = BlockService();

    try {
      await blockService.unblockUser(user.id);

      if (mounted) {
        Navigator.of(context).pop(); // Close the dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unblocked ${user.displayName ?? user.username}'),
            backgroundColor: AppColors.success,
          ),
        );

        // Refresh the blocked users dialog
        _showBlockedUsers();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to unblock user: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _toggleNotifications(bool enabled) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;

      if (user == null) {
        throw Exception('User not found');
      }

      if (enabled) {
        // Check if user has notification permissions first
        final hasPermission = await _notificationService.hasPermission();
        if (!hasPermission) {
          // Request permissions
          await _notificationService.requestPermission();

          // Check again if permission was granted
          final permissionGranted = await _notificationService.hasPermission();
          if (!permissionGranted) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Please enable notifications in your device settings',
                  ),
                  backgroundColor: AppColors.error,
                ),
              );
            }
            return;
          }
        }

        // Subscribe to topics based on user's gender
        await _notificationService.subscribeToHangoutTopicsBasedOnGender(
          user.gender,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notifications enabled'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        // Unsubscribe from all topics
        await _notificationService.unsubscribeFromTopics(user.subscribedTopics);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notifications disabled'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }

      // Update local state
      setState(() {
        _notificationsEnabled = enabled;
      });

      // Refresh user data to get updated subscribedTopics
      await authProvider.refreshCurrentUser();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update notifications: $e'),
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

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Row(
            children: [
              Icon(Icons.warning, color: AppColors.error),
              const SizedBox(width: 8),
              Text(
                'Delete Account',
                style: TextStyle(color: AppColors.textPrimary),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This action will permanently delete your account and all associated data.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              Text(
                'Are you sure you want to continue?',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.push('/profile/delete-account');
              },
              child: Text('Continue', style: TextStyle(color: AppColors.error)),
            ),
          ],
        );
      },
    );
  }
}
