import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../models/post_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/post_provider.dart';
import '../../providers/tab_navigation_provider.dart';
import '../../services/analytics_service.dart';
import '../../utils/colors.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/meetup_outcome_dialog.dart';
import '../../widgets/app_invite_modal.dart';
import 'group_members_screen.dart';

enum FeedTab { upcoming, ongoing, yourPosts }

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  FeedTab selectedTab = FeedTab.upcoming;

  @override
  void initState() {
    super.initState();
    _initializePostProvider();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Check for tab query parameter from route
    final routeState = GoRouterState.of(context);
    final tabParam = routeState.uri.queryParameters['tab'];

    if (tabParam != null) {
      debugPrint('🎯 Feed screen received tab parameter: $tabParam');

      // Set initial tab based on parameter
      switch (tabParam) {
        case 'upcoming':
          selectedTab = FeedTab.upcoming;
          break;
        case 'ongoing':
          selectedTab = FeedTab.ongoing;
          break;
        case 'hangouts':
        case 'yourPosts':
          selectedTab = FeedTab.yourPosts;
          break;
        default:
          debugPrint('⚠️ Unknown tab parameter: $tabParam, using default');
          selectedTab = FeedTab.upcoming;
      }

      debugPrint('✅ Set feed tab to: $selectedTab');
    }
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
        title: const Text('Hangouts'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: _showAppInviteModal,
            tooltip: 'Invite friends to app',
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHangoutsInfo,
            tooltip: 'How does hangouts work?',
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _navigateToCreateTab,
            tooltip: 'Add new hangout',
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTabMenu(),
          Expanded(child: _buildPostList()),
        ],
      ),
    );
  }

  Widget _buildTabMenu() {
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTabButton('Upcoming', FeedTab.upcoming),
          _buildTabButton('Ongoing', FeedTab.ongoing),
          _buildTabButton('My Hangouts', FeedTab.yourPosts),
        ],
      ),
    );
  }

  Widget _buildTabButton(String title, FeedTab tab) {
    final isSelected = selectedTab == tab;
    return GestureDetector(
      onTap: () => setState(() => selectedTab = tab),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
            width: 1,
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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

        if (filteredPosts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inbox,
                  size: 64,
                  color: AppColors.textSecondary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No hangouts yet',
                  style: TextStyle(
                    fontSize: 18,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Be the first to create a hangout!',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredPosts.length,
          itemBuilder: (context, index) {
            return _buildPostCard(filteredPosts[index]);
          },
        );
      },
    );
  }

  List<Post> _getFilteredPosts(PostProvider postProvider) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.id;
    final userGender = authProvider.currentUser?.gender;

    debugPrint('🔍 FEED DEBUG: Getting filtered posts for tab: $selectedTab');
    debugPrint('🔍 FEED DEBUG: Current user ID: $currentUserId');
    debugPrint('🔍 FEED DEBUG: User gender: $userGender');

    List<Post> filteredPosts;
    switch (selectedTab) {
      case FeedTab.upcoming:
        // Show upcoming hangouts filtered by user's gender
        debugPrint(
          '🔍 FEED DEBUG: Raw upcoming posts count: ${postProvider.upcomingPosts.length}',
        );
        filteredPosts = postProvider.getUpcomingPostsForUser(userGender);
        debugPrint(
          '🔍 FEED DEBUG: Filtered upcoming posts count: ${filteredPosts.length}',
        );
        break;
      case FeedTab.ongoing:
        // Show ongoing hangouts filtered by user's gender
        debugPrint(
          '🔍 FEED DEBUG: Raw ongoing posts count: ${postProvider.ongoingPosts.length}',
        );
        filteredPosts = postProvider.getOngoingPostsForUser(userGender);
        debugPrint(
          '🔍 FEED DEBUG: Filtered ongoing posts count: ${filteredPosts.length}',
        );
        break;
      case FeedTab.yourPosts:
        if (currentUserId == null) {
          debugPrint('🔍 FEED DEBUG: No current user, returning empty list');
          return [];
        }
        // Show all posts where user is a participant (including locked ones)
        debugPrint(
          '🔍 FEED DEBUG: Raw all posts count: ${postProvider.allPosts.length}',
        );
        filteredPosts = postProvider.allPosts
            .where(
              (post) =>
                  !post.deleted && post.participantIds.contains(currentUserId),
            )
            .toList();
        debugPrint(
          '🔍 FEED DEBUG: User posts count (participant): ${filteredPosts.length}',
        );
        break;
    }

    if (filteredPosts.isEmpty) {
      debugPrint('⚠️ FEED DEBUG: No posts found for current tab and filters!');
    } else {
      debugPrint('✅ FEED DEBUG: Showing ${filteredPosts.length} posts');
      for (int i = 0; i < filteredPosts.length && i < 3; i++) {
        final post = filteredPosts[i];
        debugPrint(
          '🔍 FEED DEBUG: Post $i: "${post.title}" (${post.id}) - Status: ${post.dynamicStatus} - Participants: ${post.participantIds.length}',
        );
      }
    }

    return filteredPosts;
  }

  Widget _buildPostCard(Post post) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          final authProvider = Provider.of<AuthProvider>(
            context,
            listen: false,
          );
          final currentUserId = authProvider.currentUser?.id;
          if (currentUserId == null) return;

          final isAuthor = post.authorId == currentUserId;
          final isParticipant = post.participantIds.contains(currentUserId);
          _viewGroup(post, isParticipant: isAuthor || isParticipant);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          post.authorName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          _getTimeText(post),
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      if (post.isLocked) ...[
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.textSecondary.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppColors.textSecondary.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.lock,
                                size: 12,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 2),
                              Text(
                                'Locked',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      _buildStatusChip(post.dynamicStatus),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                post.title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                post.description,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
              if (post.location != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      post.location!,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.people,
                        size: 16,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${post.participantIds.length} members',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  Consumer2<AuthProvider, PostProvider>(
                    builder: (context, authProvider, postProvider, child) {
                      final currentUserId = authProvider.currentUser?.id;
                      if (currentUserId == null) return const SizedBox.shrink();

                      final isAuthor = post.authorId == currentUserId;
                      final isParticipant = post.participantIds.contains(
                        currentUserId,
                      );

                      return Row(
                        children: [
                          // Show action buttons for author (Lock/Unlock and Delete)
                          if (isAuthor) ...[
                            CustomButton(
                              text: post.isLocked ? 'Unlock' : 'Lock',
                              onPressed: () =>
                                  _toggleLockPost(post, postProvider),
                              width: 65,
                              height: 32,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              backgroundColor: post.isLocked
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            CustomButton(
                              text: 'Delete',
                              onPressed: () => _deletePost(post, postProvider),
                              width: 65,
                              height: 32,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 6,
                              ),
                              backgroundColor: AppColors.error,
                            ),
                          ] else
                            const SizedBox.shrink(),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(PostStatus status) {
    Color color;
    String text;

    switch (status) {
      case PostStatus.upcoming:
        color = AppColors.primary;
        text = 'Upcoming';
        break;
      case PostStatus.ongoing:
        color = AppColors.success;
        text = 'Ongoing';
        break;
      case PostStatus.completed:
        color = AppColors.textSecondary;
        text = 'Completed';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _getTimeText(Post post) {
    final now = DateTime.now();

    // If there's a scheduled time, show that instead of creation time
    if (post.scheduledTime != null) {
      final scheduledTime = post.scheduledTime!;
      final difference = scheduledTime.difference(now);

      // If the scheduled time is in the future
      if (difference.inMinutes > 0) {
        if (difference.inMinutes < 60) {
          return 'in ${difference.inMinutes}m';
        } else if (difference.inHours < 24) {
          return 'in ${difference.inHours}h';
        } else {
          return 'in ${difference.inDays}d';
        }
      } else {
        // If the scheduled time is in the past (ongoing or completed)
        final pastDifference = now.difference(scheduledTime);
        if (pastDifference.inMinutes < 60) {
          return '${pastDifference.inMinutes}m ago';
        } else if (pastDifference.inHours < 24) {
          return '${pastDifference.inHours}h ago';
        } else {
          return '${pastDifference.inDays}d ago';
        }
      }
    } else {
      // Fallback to creation time if no scheduled time
      final difference = now.difference(post.createdAt);
      if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else {
        return '${difference.inDays}d ago';
      }
    }
  }

  void _navigateToCreateTab() {
    final tabProvider = Provider.of<TabNavigationProvider>(
      context,
      listen: false,
    );
    tabProvider.navigateToCreate();
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

  Future<void> _joinPost(
    Post post,
    String userId,
    PostProvider postProvider,
  ) async {
    final success = await postProvider.joinPost(post.id, userId);

    // Track hangout join attempt from feed screen
    if (success) {
      await AnalyticsService().trackHangoutJoined();
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Joined "${post.title}"!'
                : postProvider.error ?? 'Failed to join hangout',
          ),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
    }
  }

  Future<void> _leavePost(
    Post post,
    String userId,
    PostProvider postProvider,
  ) async {
    final success = await postProvider.leavePost(post.id, userId);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Left "${post.title}"'
                : postProvider.error ?? 'Failed to leave hangout',
          ),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
    }
  }

  Future<void> _deletePost(Post post, PostProvider postProvider) async {
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Deleted "${post.title}"'
                  : postProvider.error ?? 'Failed to delete hangout',
            ),
            backgroundColor: success ? AppColors.success : AppColors.error,
          ),
        );
      }
      return;
    }

    // Show feedback dialog for immediate author feedback
    await MeetupOutcomeDialog.show(
      context,
      hangoutTitle: post.title,
      onCancel: () {
        // User cancelled deletion - do nothing
      },
      onConfirmDelete: (didMeetup) async {
        // Track meetup feedback
        await AnalyticsService().trackMeetupSuccess(didMeetup);

        // User confirmed deletion with feedback - proceed with deletion
        final success = await postProvider.deletePostWithFeedback(
          post.id,
          currentUser.id,
          authorDidMeetup: didMeetup,
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                success
                    ? 'Deleted "${post.title}" and saved feedback'
                    : postProvider.error ?? 'Failed to delete hangout',
              ),
              backgroundColor: success ? AppColors.success : AppColors.error,
            ),
          );
        }
      },
    );
  }

  Future<void> _toggleLockPost(Post post, PostProvider postProvider) async {
    final bool isLocking = !post.isLocked;

    // If locking, show confirmation dialog
    if (isLocking) {
      final bool? shouldLock = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: AppColors.surface,
            title: Row(
              children: [
                Icon(Icons.lock_outline, color: AppColors.primary, size: 24),
                const SizedBox(width: 8),
                const Text('Lock Hangout'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Locking "${post.title}" will:',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.visibility_off,
                      color: AppColors.textSecondary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Hide it from discovery - no one new can find or join it',
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
                        'Can be unlocked later to make it discoverable again',
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
                child: const Text('Lock Hangout'),
              ),
            ],
          );
        },
      );

      if (shouldLock != true) return; // User cancelled
    }

    final String action = isLocking ? 'lock' : 'unlock';
    final String actionPast = isLocking ? 'locked' : 'unlocked';

    final bool success = isLocking
        ? await postProvider.lockPost(post.id)
        : await postProvider.unlockPost(post.id);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Hangout "${post.title}" has been $actionPast'
                : postProvider.error ?? 'Failed to $action hangout',
          ),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
    }
  }

  void _viewGroup(Post post, {required bool isParticipant}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            GroupMembersScreen(post: post, isParticipant: isParticipant),
      ),
    );
  }
}
