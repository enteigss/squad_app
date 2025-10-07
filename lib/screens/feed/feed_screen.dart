import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../models/post_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/post_provider.dart';
import '../../providers/tab_navigation_provider.dart';
import '../../services/analytics_service.dart';
import '../../services/debug_service.dart';
import '../../services/firestore_service.dart';
import '../../utils/colors.dart';
import '../../widgets/meetup_outcome_dialog.dart';
import '../../widgets/app_invite_modal.dart';
import '../../widgets/profile_avatar.dart';
import 'hangout_screen.dart';

enum FeedTab { upcoming, ongoing, yourPosts }

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  FeedTab selectedTab = FeedTab.upcoming;
  final DebugService _debugService = DebugService();
  bool _isCreatingDebugPosts = false;
  bool _isDeletingDebugPosts = false;
  bool _showDebugToolbar = true;

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
          if (kDebugMode)
            IconButton(
              icon: Icon(_showDebugToolbar ? Icons.visibility_off : Icons.visibility),
              onPressed: () {
                setState(() {
                  _showDebugToolbar = !_showDebugToolbar;
                });
              },
              tooltip: _showDebugToolbar ? 'Hide debug toolbar' : 'Show debug toolbar',
              color: Colors.white,
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
          if (kDebugMode && _showDebugToolbar) _buildDebugToolbar(),
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
          child: Stack(
            children: [
              // Main content
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top row: Profile picture + name (author only)
                  _buildTopRow(post),

                  const SizedBox(height: 16),

                  // Middle section: Title, location, description
                  _buildMiddleSection(post),

                  const SizedBox(height: 16),

                  // Bottom row: Group member count + author actions
                  _buildBottomRow(post),
                ],
              ),

              // Status positioned in top right corner
              Positioned(top: 0, right: 0, child: _buildStatusElement(post)),

              // Menu positioned in bottom right corner (for authors only)
              Positioned(bottom: -8, right: -8, child: _buildPostMenu(post)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePicture(String authorId) {
    return FutureBuilder<UserModel?>(
      future: _getUserData(authorId),
      builder: (context, snapshot) {
        final user = snapshot.data;

        return ProfileAvatar(
          imageUrl: user?.photoUrl,
          name: user?.displayName ?? user?.username,
          radius: 14,
          backgroundColor: AppColors.textSecondary.withValues(alpha: 0.1),
          textColor: AppColors.textSecondary.withValues(alpha: 0.7),
        );
      },
    );
  }

  Future<UserModel?> _getUserData(String userId) async {
    try {
      final firestoreService = FirestoreService();
      final user = await firestoreService.getUser(userId);
      return user;
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      return null;
    }
  }

  Widget _buildTopRow(Post post) {
    return Row(
      children: [
        // Profile picture and name (author info only)
        Row(
          children: [
            // Profile picture
            _buildProfilePicture(post.authorId),
            const SizedBox(width: 8),
            // Name
            Text(
              post.authorName,
              style: TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),

        // Close indicator (if closed)
        if (post.isLocked) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: AppColors.textSecondary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock,
                  size: 8,
                  color: AppColors.textSecondary.withValues(alpha: 0.7),
                ),
                const SizedBox(width: 2),
                Text(
                  'Closed',
                  style: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                    fontSize: 8,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStatusElement(Post post) {
    final isOngoing = post.dynamicStatus == PostStatus.ongoing;

    if (isOngoing) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.4)),
        ),
        child: Text(
          'Ongoing',
          style: TextStyle(
            color: AppColors.success,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.textSecondary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          _getTimeText(post),
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }
  }

  Widget _buildPostMenu(Post post) {
    return Consumer2<AuthProvider, PostProvider>(
      builder: (context, authProvider, postProvider, child) {
        final currentUserId = authProvider.currentUser?.id;
        if (currentUserId == null) return const SizedBox.shrink();

        final isAuthor = post.authorId == currentUserId;
        if (!isAuthor) return const SizedBox.shrink();

        return PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: AppColors.textSecondary, size: 14),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
          offset: const Offset(-16, 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          color: AppColors.surface,
          onSelected: (value) {
            switch (value) {
              case 'lock':
                _toggleLockPost(post, postProvider);
                break;
              case 'delete':
                _deletePost(post, postProvider);
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'lock',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    post.isLocked ? Icons.lock_open : Icons.lock,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    post.isLocked ? 'Open' : 'Close',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delete, size: 18, color: AppColors.error),
                  const SizedBox(width: 8),
                  Text(
                    'Delete',
                    style: TextStyle(color: AppColors.error, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMiddleSection(Post post) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Text(
          post.title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
        ),

        const SizedBox(height: 4),

        // Location below title
        Row(
          children: [
            Icon(Icons.location_on, size: 14, color: AppColors.primary),
            const SizedBox(width: 3),
            Text(
              post.location ?? 'GSU',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Description
        Text(
          post.description,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomRow(Post post) {
    return Row(
      children: [
        // Group member count
        Icon(Icons.people, size: 18, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(
          '${post.participantIds.length} ${post.participantIds.length == 1 ? 'member' : 'members'}',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
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
    // If there's a scheduled time, show that
    if (post.scheduledTime != null) {
      final scheduledTime = post.scheduledTime!;
      final now = DateTime.now();

      // Show time in format like "2:30 PM" for today, or "Mon 2:30 PM" for other days
      if (_isSameDay(scheduledTime, now)) {
        return _formatTime(scheduledTime);
      } else if (_isWithinWeek(scheduledTime, now)) {
        return '${_formatWeekday(scheduledTime)} ${_formatTime(scheduledTime)}';
      } else {
        return '${_formatDate(scheduledTime)} ${_formatTime(scheduledTime)}';
      }
    } else {
      // Fallback to creation time if no scheduled time
      final createdTime = post.createdAt;
      final now = DateTime.now();

      if (_isSameDay(createdTime, now)) {
        return _formatTime(createdTime);
      } else if (_isWithinWeek(createdTime, now)) {
        return '${_formatWeekday(createdTime)} ${_formatTime(createdTime)}';
      } else {
        return '${_formatDate(createdTime)} ${_formatTime(createdTime)}';
      }
    }
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  bool _isWithinWeek(DateTime date, DateTime now) {
    final difference = now.difference(date).inDays.abs();
    return difference <= 7;
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

  String _formatWeekday(DateTime dateTime) {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return weekdays[dateTime.weekday - 1];
  }

  String _formatDate(DateTime dateTime) {
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
      await AnalyticsService().trackHangoutJoined(
        userId: userId,
        hangoutId: post.id,
      );
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
        await AnalyticsService().trackMeetupSuccess(
          didMeetup: didMeetup,
          hangoutId: post.id,
        );

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

    // If closing, show confirmation dialog
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
                const Text('Close Hangout'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Closing "${post.title}" will:',
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
                        'Can be opened later to make it discoverable again',
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
                child: const Text('Close Hangout'),
              ),
            ],
          );
        },
      );

      if (shouldLock != true) return; // User cancelled
    }

    final String action = isLocking ? 'close' : 'open';
    final String actionPast = isLocking ? 'closed' : 'opened';

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
    context.push('/group-members/${post.id}');
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
              Icon(
                Icons.bug_report,
                color: AppColors.error,
                size: 16,
              ),
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
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Create Sample Posts'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isDeletingDebugPosts ? null : _deleteAllDebugPosts,
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
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
