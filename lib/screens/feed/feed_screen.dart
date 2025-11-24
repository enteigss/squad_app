import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../models/post_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/post_provider.dart';
import '../../providers/tab_navigation_provider.dart';
import '../../services/analytics_service.dart';
import '../../services/debug_service.dart';
import '../../utils/colors.dart';
import '../../widgets/app_invite_modal.dart';
import '../../widgets/post_card.dart';
import '../../widgets/create_post_bottom_sheet.dart';
import 'hangout_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  // Time filter state
  bool _nowSelected = true;
  bool _laterSelected = true;

  // Type filter state (emojis)
  bool _walkingSelected = true;
  bool _raisingSelected = true;
  bool _wavingSelected = true;

  final DebugService _debugService = DebugService();
  bool _isCreatingDebugPosts = false;
  bool _isDeletingDebugPosts = false;
  bool _showDebugToolbar = true;

  @override
  void initState() {
    super.initState();
    _initializePostProvider();
  }

  void _initializePostProvider() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final postProvider = Provider.of<PostProvider>(context, listen: false);
      postProvider.initialize();

      // Load user hangouts if we have a current user
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;
      if (currentUser != null) {
        postProvider.loadUserPosts(currentUser.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Home'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          if (kDebugMode)
            IconButton(
              icon: Icon(
                _showDebugToolbar ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () {
                setState(() {
                  _showDebugToolbar = !_showDebugToolbar;
                });
              },
              tooltip: _showDebugToolbar
                  ? 'Hide debug toolbar'
                  : 'Show debug toolbar',
              color: Colors.white,
            ),
        ],
      ),
      body: Column(
        children: [
          _buildTabMenu(),
          Expanded(child: _buildPostList()),
          if (kDebugMode && _showDebugToolbar) _buildDebugToolbar(),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 0),
        child: FloatingActionButton.small(
          onPressed: () {
            final authProvider = Provider.of<AuthProvider>(
              context,
              listen: false,
            );
            final currentUser = authProvider.currentUser;
            if (currentUser != null) {
              final userName =
                  currentUser.displayName?.split(' ').first ??
                  currentUser.username;
              CreatePostBottomSheet.show(context, userName);
            }
          },
          backgroundColor: AppColors.primary,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildTabMenu() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Row(
        children: [
          // Left section - Time filters
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildToggleButton('Now', _nowSelected, () {
                  setState(() => _nowSelected = !_nowSelected);
                }),
                _buildToggleButton('Later', _laterSelected, () {
                  setState(() => _laterSelected = !_laterSelected);
                }),
              ],
            ),
          ),

          // Vertical divider
          Container(
            width: 1,
            height: 30,
            color: AppColors.textSecondary.withValues(alpha: 0.2),
            margin: const EdgeInsets.symmetric(horizontal: 12),
          ),

          // Right section - Type filters (emojis)
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildToggleButton('🚶', _walkingSelected, () {
                  setState(() => _walkingSelected = !_walkingSelected);
                }),
                _buildToggleButton('🙋', _raisingSelected, () {
                  setState(() => _raisingSelected = !_raisingSelected);
                }),
                _buildToggleButton('👋', _wavingSelected, () {
                  setState(() => _wavingSelected = !_wavingSelected);
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.textSecondary.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildPostList() {
    return Consumer<PostProvider>(
      builder: (context, postProvider, child) {
        if (postProvider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        if (postProvider.error != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: AppColors.error.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'Error loading hangouts',
                  style: TextStyle(fontSize: 18, color: AppColors.error),
                ),
                const SizedBox(height: 8),
                Text(
                  postProvider.error!,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => postProvider.initialize(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final filteredPosts = _getFilteredPosts(postProvider);

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredPosts.length + 3, // +3 for info cards
          itemBuilder: (context, index) {
            // Show info cards first
            if (index == 0) {
              return _buildInfoCard(
                emoji: '🚶',
                text: 'Got plans? Let people join you.',
                postType: PostType.walking,
              );
            }
            if (index == 1) {
              return _buildInfoCard(
                emoji: '🙋',
                text: 'Need a group? Find people here.',
                postType: PostType.raising,
              );
            }
            if (index == 2) {
              return _buildInfoCard(
                emoji: '👋',
                text: 'No plans? Let people know you\'re free.',
                postType: PostType.waving,
              );
            }
            // Show hangout cards after info cards
            return PostCard(post: filteredPosts[index - 3]);
          },
        );
      },
    );
  }

  List<Post> _getFilteredPosts(PostProvider postProvider) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.id;
    final userGender = authProvider.currentUser?.gender;

    debugPrint('🔍 FEED DEBUG: Getting filtered posts');
    debugPrint('🔍 FEED DEBUG: Current user ID: $currentUserId');
    debugPrint('🔍 FEED DEBUG: User gender: $userGender');

    // For now, show all posts (both upcoming and ongoing) until filters are functional
    // Combine upcoming and ongoing posts
    final upcomingPosts = postProvider.getUpcomingPostsForUser(userGender);
    final ongoingPosts = postProvider.getOngoingPostsForUser(userGender);

    List<Post> filteredPosts = [...upcomingPosts, ...ongoingPosts];

    // Sort by soonest first: ongoing posts first, then upcoming by scheduled time
    filteredPosts.sort((a, b) {
      final aIsOngoing = a.dynamicStatus == PostStatus.ongoing;
      final bIsOngoing = b.dynamicStatus == PostStatus.ongoing;

      // Ongoing posts come first
      if (aIsOngoing && !bIsOngoing) return -1;
      if (!aIsOngoing && bIsOngoing) return 1;

      // Within same status, sort by scheduled time (soonest first)
      final aTime = a.scheduledTime ?? a.createdAt;
      final bTime = b.scheduledTime ?? b.createdAt;
      return aTime.compareTo(bTime);
    });

    debugPrint('🔍 FEED DEBUG: Upcoming posts: ${upcomingPosts.length}');
    debugPrint('🔍 FEED DEBUG: Ongoing posts: ${ongoingPosts.length}');
    debugPrint('🔍 FEED DEBUG: Total filtered posts: ${filteredPosts.length}');

    if (filteredPosts.isEmpty) {
      debugPrint('⚠️ FEED DEBUG: No posts found!');
    } else {
      debugPrint('✅ FEED DEBUG: Showing ${filteredPosts.length} posts');
      for (int i = 0; i < filteredPosts.length && i < 3; i++) {
        final post = filteredPosts[i];
        debugPrint(
          '🔍 FEED DEBUG: Post $i: (${post.id}) - Status: ${post.dynamicStatus} - Participants: ${post.participantIds.length}',
        );
      }
    }

    return filteredPosts;
  }

  Widget _buildInfoCard({
    required String emoji,
    required String text,
    required PostType postType,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      height: 50,
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () {
            final authProvider = Provider.of<AuthProvider>(
              context,
              listen: false,
            );
            final currentUser = authProvider.currentUser;
            if (currentUser != null) {
              final userName =
                  currentUser.displayName?.split(' ').first ??
                  currentUser.username;
              CreatePostBottomSheet.show(
                context,
                userName,
                initialPostType: postType,
              );
            }
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.textSecondary.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              children: [
                Text(emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.3,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAppInviteModal() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be signed in to invite friends'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    AppInviteModal.show(
      context,
      inviterUserId: currentUser.id,
      inviterName: currentUser.displayName ?? currentUser.username,
    );
  }

  Future<void> _showHangoutsInfo() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.help_outline, color: AppColors.primary, size: 24),
              const SizedBox(width: 8),
              const Text('How does Hangouts work?'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoSection(
                  icon: Icons.group_add,
                  title: 'Create & Join',
                  description:
                      'Create hangouts for activities you want to do or join existing ones that interest you.',
                ),
                const SizedBox(height: 16),
                _buildInfoSection(
                  icon: Icons.people,
                  title: 'View Groups',
                  description:
                      'See who\'s joined each hangout and chat with group members before meeting up.',
                ),
                const SizedBox(height: 16),
                _buildInfoSection(
                  icon: Icons.filter_alt,
                  title: 'Smart Filtering',
                  description:
                      'Hangouts are filtered by your gender preferences for safer, more comfortable experiences.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Got it!'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoSection({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDebugToolbar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        border: Border(
          top: BorderSide(
            color: AppColors.error.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.bug_report, color: AppColors.error, size: 16),
              const SizedBox(width: 8),
              Text(
                'DEBUG MODE',
                style: TextStyle(
                  color: AppColors.error,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isCreatingDebugPosts ? null : _createSamplePosts,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _isCreatingDebugPosts
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text('Create Sample Posts'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isDeletingDebugPosts
                      ? null
                      : _deleteAllDebugPosts,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _isDeletingDebugPosts
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text('Delete Debug Posts'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _createSamplePosts() async {
    setState(() {
      _isCreatingDebugPosts = true;
    });

    try {
      await _debugService.createSamplePosts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Created 5 sample posts + profiles + chat messages'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 4),
          ),
        );
        // Refresh the post provider to show new posts
        final postProvider = Provider.of<PostProvider>(context, listen: false);
        postProvider.initialize();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create sample posts: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingDebugPosts = false;
        });
      }
    }
  }

  Future<void> _deleteAllDebugPosts() async {
    setState(() {
      _isDeletingDebugPosts = true;
    });

    try {
      await _debugService.deleteAllDebugPosts();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Deleted all debug posts, profiles, and chat'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 4),
          ),
        );
        // Refresh the post provider to remove deleted posts
        final postProvider = Provider.of<PostProvider>(context, listen: false);
        postProvider.initialize();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete debug posts: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeletingDebugPosts = false;
        });
      }
    }
  }
}
