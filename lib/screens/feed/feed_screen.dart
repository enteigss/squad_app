import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../models/post_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/post_provider.dart';
import '../../utils/colors.dart';
import '../../widgets/custom_button.dart';
import 'create_post_screen.dart';
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

  void _initializePostProvider() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final postProvider = Provider.of<PostProvider>(context, listen: false);
      postProvider.initialize();
      
      // Load user posts if we have a current user
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
        title: const Text('Who\'s Down'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addNewPost,
            tooltip: 'Add new post',
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
          _buildTabButton('My Posts', FeedTab.yourPosts),
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
                  'Error loading posts',
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
                  'No posts yet',
                  style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                Text(
                  'Be the first to create a post!',
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
    final currentUserId =
        Provider.of<AuthProvider>(context, listen: false).currentUser?.id;

    switch (selectedTab) {
      case FeedTab.upcoming:
        // Show all upcoming posts from all users
        return postProvider.upcomingPosts;
      case FeedTab.ongoing:
        // Show all ongoing posts from all users
        return postProvider.ongoingPosts;
      case FeedTab.yourPosts:
        return currentUserId != null ? postProvider.userPosts : [];
    }
  }

  Widget _buildPostCard(Post post) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Icon(Icons.person, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
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
                _buildStatusChip(post.dynamicStatus),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              post.title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                      '${post.participantIds.length}/${post.maxParticipants}',
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
                    final isParticipant = post.participantIds.contains(currentUserId);

                    return Row(
                      children: [
                        // Show View Group button if user is a participant (author or joined member)
                        if (isAuthor || isParticipant) ...[
                          CustomButton(
                            text: 'View Group',
                            onPressed: () => _viewGroup(post),
                            width: 100,
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            backgroundColor: AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                        ],
                        
                        // Show action button (Delete/Leave/Join)
                        if (isAuthor) 
                          CustomButton(
                            text: 'Delete',
                            onPressed: () => _deletePost(post, postProvider),
                            width: 90,
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            backgroundColor: AppColors.error,
                          )
                        else if (isParticipant)
                          CustomButton(
                            text: 'Leave',
                            onPressed: () => _leavePost(post, currentUserId, postProvider),
                            width: 90,
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            backgroundColor: AppColors.error,
                          )
                        else if (postProvider.canUserJoinPost(post, currentUserId))
                          CustomButton(
                            text: 'Join',
                            onPressed: () => _joinPost(post, currentUserId, postProvider),
                            width: 90,
                            height: 36,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          )
                        else
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

  void _addNewPost() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreatePostScreen(),
      ),
    );
  }

  Future<void> _joinPost(Post post, String userId, PostProvider postProvider) async {
    final success = await postProvider.joinPost(post.id, userId);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success 
              ? 'Joined "${post.title}"!' 
              : postProvider.error ?? 'Failed to join post'),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
    }
  }

  Future<void> _leavePost(Post post, String userId, PostProvider postProvider) async {
    final success = await postProvider.leavePost(post.id, userId);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success 
              ? 'Left "${post.title}"' 
              : postProvider.error ?? 'Failed to leave post'),
          backgroundColor: success ? AppColors.success : AppColors.error,
        ),
      );
    }
  }

  Future<void> _deletePost(Post post, PostProvider postProvider) async {
    // Show confirmation dialog
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Post'),
          content: Text('Are you sure you want to delete "${post.title}"? This action cannot be undone.'),
          backgroundColor: AppColors.surface,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (shouldDelete == true) {
      final success = await postProvider.deletePost(post.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success 
                ? 'Deleted "${post.title}"' 
                : postProvider.error ?? 'Failed to delete post'),
            backgroundColor: success ? AppColors.success : AppColors.error,
          ),
        );
      }
    }
  }

  void _viewGroup(Post post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupMembersScreen(post: post),
      ),
    );
  }
}
