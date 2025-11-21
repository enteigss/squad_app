import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/post_model.dart';
import '../../models/user_model.dart';
import '../../models/report_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/post_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/report_service.dart';
import '../../utils/colors.dart';
import '../../widgets/profile_avatar.dart';
import '../profile/profile_detail_screen.dart';
import '../../widgets/invite_options_modal.dart';
import '../../widgets/report_dialog.dart';
import '../../widgets/censored_profile_card.dart';
import '../../widgets/edit_hangout_dialog.dart';
import '../../services/block_service.dart';
import '../../services/analytics_service.dart';
import '../../services/notification_service.dart';

class HangoutScreen extends StatefulWidget {
  final Post post;
  final bool isParticipant;

  const HangoutScreen({
    super.key,
    required this.post,
    this.isParticipant = true, // Default to true for backward compatibility
  });

  @override
  State<HangoutScreen> createState() => _HangoutScreenState();
}

class _HangoutScreenState extends State<HangoutScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final ReportService _reportService = ReportService();
  final BlockService _blockService = BlockService();
  final NotificationService _notificationService = NotificationService();
  List<UserModel> _members = [];
  bool _isLoading = true;
  String _currentDescription = '';
  DateTime? _currentScheduledTime;
  String? _currentLocation;
  String? _error;
  bool _currentUserIsParticipant = false;
  bool _chatNotificationsEnabled = true;
  bool _loadingNotificationPref = false;
  bool _isJoiningOrLeaving = false;

  @override
  void initState() {
    super.initState();
    _currentDescription = widget.post.description!;
    _currentScheduledTime = widget.post.scheduledTime;
    _currentLocation = widget.post.location;
    _loadGroupMembers();
    _loadNotificationPreference();
  }

  Future<void> _loadNotificationPreference() async {
    try {
      final enabled = await _notificationService
          .getHangoutChatNotificationPreference(widget.post.id);
      if (mounted) {
        setState(() {
          _chatNotificationsEnabled = enabled;
        });
      }
    } catch (e) {
      debugPrint('Error loading notification preference: $e');
    }
  }

  Future<void> _toggleChatNotifications() async {
    if (_loadingNotificationPref) return;

    // Optimistic update
    final previousValue = _chatNotificationsEnabled;
    setState(() {
      _chatNotificationsEnabled = !_chatNotificationsEnabled;
      _loadingNotificationPref = true;
    });

    try {
      await _notificationService.toggleHangoutChatNotifications(
        widget.post.id,
        _chatNotificationsEnabled,
      );

      if (mounted) {
        setState(() {
          _loadingNotificationPref = false;
        });

        // Show confirmation
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _chatNotificationsEnabled
                  ? 'Chat notifications enabled'
                  : 'Chat notifications disabled',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Rollback on error
      if (mounted) {
        setState(() {
          _chatNotificationsEnabled = previousValue;
          _loadingNotificationPref = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to update notification settings'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      debugPrint('Error toggling chat notifications: $e');
    }
  }

  Future<void> _loadGroupMembers([Post? post]) async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final members = <UserModel>[];

      // Use the provided post or fallback to widget.post
      final currentPost = post ?? widget.post;

      // Get current user ID to check participation
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUserId = authProvider.currentUser?.id;

      // Load each participant's user data
      for (final participantId in currentPost.participantIds) {
        try {
          final user = await _firestoreService.getUser(participantId);
          if (user != null) {
            members.add(user);
          }
        } catch (e) {
          // Continue loading other members even if one fails
          debugPrint('Failed to load user $participantId: $e');
        }
      }

      setState(() {
        _members = members;
        _currentUserIsParticipant =
            currentUserId != null &&
            currentPost.participantIds.contains(currentUserId);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load group members: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Use local state instead of Consumer to avoid rebuilds from PostProvider timer
    final currentPost = widget.post; // Use original post data
    final effectiveLimit = currentPost.maxParticipants ?? 100;
    final bool isGroupFull = _members.length >= effectiveLimit;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Check if we came from a notification
            final routeState = GoRouterState.of(context);
            final fromNotification =
                routeState.uri.queryParameters['from'] == 'notification';

            if (fromNotification) {
              // Navigate to feed hangouts tab if came from notification
              context.go('/feed?tab=yourPosts');
            } else {
              // Use GoRouter to go back
              context.pop();
            }
          },
        ),
        title: Text(
          _currentUserIsParticipant
              ? 'Group Members (${_members.length})'
              : 'Group Preview (${_members.length})',
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Edit button - show only for owner
          if (_isOwner())
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: _showEditHangoutDialog,
              tooltip: 'Edit Hangout',
            ),
          // Chat notification toggle - show only for participants
          if (_currentUserIsParticipant)
            IconButton(
              icon: Icon(
                _chatNotificationsEnabled
                    ? Icons.notifications
                    : Icons.notifications_off,
              ),
              onPressed: _toggleChatNotifications,
              tooltip: _chatNotificationsEnabled
                  ? 'Disable chat notifications'
                  : 'Enable chat notifications',
            ),
          // Report button - show for all users who are not the host
          if (_canShowReportButton())
            IconButton(
              icon: const Icon(Icons.flag_outlined),
              onPressed: _showReportDialog,
              tooltip: 'Report Hangout',
            ),
        ],
      ),
      body: Column(
        children: [
          // Post info header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: AppColors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow(
                  Icons.schedule,
                  _formatTimeDisplay(_currentScheduledTime),
                  isBold: _isOngoing(_currentScheduledTime),
                ),
                const SizedBox(height: 8),
                if (_currentLocation != null && _currentLocation!.isNotEmpty)
                  _buildInfoRow(Icons.location_on, _currentLocation!),
                if (_currentLocation != null && _currentLocation!.isNotEmpty)
                  const SizedBox(height: 8),
                if (_currentDescription.isNotEmpty)
                  _buildInfoRow(Icons.description, _currentDescription),
                if (_currentDescription.isNotEmpty) const SizedBox(height: 8),
                _buildInfoRow(Icons.people, '${_members.length} members'),
              ],
            ),
          ),

          // Preview notice for non-participants
          if (!_currentUserIsParticipant)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: AppColors.primary.withValues(alpha: 0.1),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You\'re viewing this group in preview mode. Join the group to access chat and full features.',
                      style: TextStyle(color: AppColors.primary, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),

          // Members list
          Expanded(child: _buildMembersList()),
        ],
      ),
      bottomNavigationBar: _shouldShowParticipantActions(currentPost)
          ? _buildBottomActions(isGroupFull, currentPost)
          : _buildJoinBottomAction(),
    );
  }

  bool _shouldShowParticipantActions(Post currentPost) {
    // Use local state instead of checking post data
    return _currentUserIsParticipant;
  }

  Widget _buildBottomActions(bool isGroupFull, Post currentPost) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.id;
    if (currentUserId == null) return const SizedBox.shrink();

    final bool isAuthor = currentUserId == currentPost.authorId;
    final bool showInvite = !isGroupFull;
    final bool showChat = true; // Always show chat for participants
    final bool showLeave = !isAuthor; // Show leave button for non-authors

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      color: AppColors.background,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildActionButtons(
            showInvite,
            showChat,
            showLeave,
            currentUserId,
            currentPost,
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    bool showInvite,
    bool showChat,
    bool showLeave,
    String currentUserId,
    Post currentPost,
  ) {
    final List<Widget> widgets = [];

    // Invite Friends button on its own row (only for authors)
    if (showInvite) {
      widgets.add(
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _openInviteModal(currentPost),
            icon: const Icon(Icons.person_add, size: 18),
            label: const Text('Invite Friends'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      );

      // Add spacing between invite button and bottom row
      if (showChat || showLeave) {
        widgets.add(const SizedBox(height: 12));
      }
    }

    // Bottom row with Chat and Leave buttons
    final List<Widget> bottomRowButtons = [];

    // Group Chat button
    if (showChat) {
      bottomRowButtons.add(
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _openChat(currentPost),
            icon: const Icon(Icons.chat, size: 18),
            label: const Text('Group Chat'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      );
    }

    // Leave button (only for non-authors)
    if (showLeave) {
      if (bottomRowButtons.isNotEmpty) {
        bottomRowButtons.add(const SizedBox(width: 12));
      }
      bottomRowButtons.add(
        Expanded(
          child: ElevatedButton.icon(
            onPressed: _isJoiningOrLeaving
                ? null
                : () => _leavePost(currentUserId),
            icon: _isJoiningOrLeaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.exit_to_app, size: 18),
            label: Text(_isJoiningOrLeaving ? 'Leaving...' : 'Leave Group'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      );
    }

    // Add bottom row if there are buttons
    if (bottomRowButtons.isNotEmpty) {
      widgets.add(Row(children: bottomRowButtons));
    }

    return widgets.isEmpty
        ? const SizedBox.shrink()
        : Column(children: widgets);
  }

  Widget _buildJoinBottomAction() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final postProvider = Provider.of<PostProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.id;

    if (currentUserId == null) return const SizedBox.shrink();

    final canJoin = postProvider.canUserJoinPost(
      widget.post,
      currentUserId,
      userGender: authProvider.currentUser?.gender,
    );

    if (!canJoin) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      color: AppColors.background,
      child: ElevatedButton.icon(
        onPressed: _isJoiningOrLeaving
            ? null
            : () => _joinPost(currentUserId, postProvider),
        icon: _isJoiningOrLeaving
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.login, size: 18),
        label: Text(_isJoiningOrLeaving ? 'Joining...' : 'Join Hangout'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  // NEW: Method to handle opening the invite modal.
  void _openInviteModal(Post currentPost) {
    // Get the current user's name from AuthProvider
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final inviterName = authProvider.currentUser?.displayName ?? 'A friend';

    // This assumes you have an InviteOptionsModal with a static `show` method.
    // The Navigator.pop() call from your example is removed as it's not needed here.
    InviteOptionsModal.show(
      context,
      hangoutId: currentPost.id,
      inviterName: inviterName,
    );
  }

  Widget _buildMembersList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_error != null) {
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
              'Error loading members',
              style: TextStyle(fontSize: 18, color: AppColors.error),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadGroupMembers,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_members.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No members found',
              style: TextStyle(fontSize: 18, color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _members.length,
      itemBuilder: (context, index) {
        return FutureBuilder<Widget>(
          future: _buildMemberCard(_members[index]),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(radius: 24),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          children: [
                            LinearProgressIndicator(),
                            SizedBox(height: 8),
                            Text('Loading...', style: TextStyle(fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return snapshot.data ?? const SizedBox.shrink();
          },
        );
      },
    );
  }

  Future<Widget> _buildMemberCard(UserModel member) async {
    final currentUserId = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).currentUser?.id;
    final isCurrentUser = member.id == currentUserId;
    final isAuthor = member.id == widget.post.authorId;

    // Don't censor current user's own profile
    if (isCurrentUser) {
      return _buildRegularMemberCard(member, isCurrentUser, isAuthor);
    }

    // Check if current user has blocked this member
    if (currentUserId != null) {
      final isBlocked = await _blockService.isBlocked(member.id);
      if (isBlocked) {
        return CensoredProfileCard(memberId: member.id, isAuthor: isAuthor);
      }
    }

    return _buildRegularMemberCard(member, isCurrentUser, isAuthor);
  }

  Widget _buildRegularMemberCard(
    UserModel member,
    bool isCurrentUser,
    bool isAuthor,
  ) {
    final currentUserId = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).currentUser?.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppColors.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _viewProfile(member),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Profile picture
              ProfileAvatar(
                imageUrl: member.photoUrl,
                name: member.displayName ?? 'Unknown User',
                radius: 24,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                textColor: AppColors.primary,
              ),
              const SizedBox(width: 16),

              // Member info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            member.displayName ?? 'Unknown User',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (isCurrentUser) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'You',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        if (isAuthor) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Host',
                              style: TextStyle(
                                color: AppColors.success,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (member.bio != null && member.bio!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        member.bio!,
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    if (member.interests.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: member.interests.take(3).map((interest) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.textSecondary.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              interest,
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),

              // Profile view indicator and remove button
              Row(
                children: [
                  // Tap to view profile indicator
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppColors.textSecondary.withValues(alpha: 0.5),
                  ),

                  // Remove button (only show for host when viewing other members)
                  if (_canRemoveMember(currentUserId, member.id)) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _showRemoveMemberDialog(member),
                      icon: Icon(
                        Icons.remove_circle_outline,
                        color: AppColors.error,
                      ),
                      tooltip: 'Remove member',
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Check if current user can remove a member
  bool _canRemoveMember(String? currentUserId, String memberId) {
    // Only participants can remove members
    if (!_currentUserIsParticipant) return false;

    // Only the post author (host) can remove members
    if (currentUserId != widget.post.authorId) return false;

    // Can't remove yourself
    if (currentUserId == memberId) return false;

    // Must have at least 2 people to show remove option
    if (widget.post.participantIds.length <= 1) return false;

    return true;
  }

  Future<void> _showRemoveMemberDialog(UserModel member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Remove Group Member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Do you want to remove ${member.displayName ?? 'this member'} from the group for inactivity?',
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This feature is intended for removing inactive members who haven\'t been participating in the group.',
                      style: TextStyle(color: AppColors.primary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
              ),
              child: const Text('Remove Member'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _removeMember(member);
    }
  }

  Future<void> _removeMember(UserModel member) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );

      // Remove member from post
      await _firestoreService.removeMemberFromPost(widget.post.id, member.id);

      // Dismiss loading dialog
      if (mounted) Navigator.of(context).pop();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${member.displayName ?? 'Member'} has been removed from the group',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }

      // Reload members list
      await _loadGroupMembers();
    } catch (e) {
      // Dismiss loading dialog
      if (mounted) Navigator.of(context).pop();

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to remove member: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _openChat(Post currentPost) {
    context.push('/post-chat/${currentPost.id}');
  }

  void _viewProfile(UserModel member) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileDetailScreen(user: member),
      ),
    );
  }

  // Check if current user can see the report button
  bool _canShowReportButton() {
    final currentUserId = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).currentUser?.id;

    // Don't show report button to the host
    return currentUserId != widget.post.authorId;
  }

  // Show report dialog
  Future<void> _showReportDialog() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be signed in to report content'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    try {
      await ReportDialog.show(
        context,
        contentType: 'hangout',
        contentId: widget.post.id,
        authorId: widget.post.authorId,
        contentSnippet: ReportService.createHangoutContentSnippet(
          title: "Placeholder Title",
          description: widget.post.description!,
          location: widget.post.location,
          participantCount: widget.post.participantIds.length,
          scheduledTime: widget.post.scheduledTime,
        ),
        onSubmit: (ReportReason reason) => _submitReport(reason, currentUser),
      );
    } catch (e) {
      if (mounted) {
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
  Future<void> _submitReport(ReportReason reason, UserModel currentUser) async {
    try {
      await _reportService.submitReport(
        contentTitle: "Placeholder title",
        contentType: 'hangout',
        contentId: widget.post.id,
        authorId: widget.post.authorId,
        contentSnippet: ReportService.createHangoutContentSnippet(
          title: "Placeholder title",
          description: widget.post.description!,
          location: widget.post.location,
          participantCount: widget.post.participantIds.length,
          scheduledTime: widget.post.scheduledTime,
        ),
        reason: reason,
        reporterUid: currentUser.id,
        reporterDisplayName: currentUser.displayName ?? 'Unknown User',
      );

      if (mounted) {
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
      if (mounted) {
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

  // Helper method to build info row
  Widget _buildInfoRow(IconData icon, String text, {bool isBold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  bool _isOwner() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.id;
    return currentUserId == widget.post.authorId;
  }

  Future<void> _showEditHangoutDialog() async {
    // Create a post object with current state values for the dialog
    final currentPost = widget.post.copyWith(
      description: _currentDescription,
      scheduledTime: _currentScheduledTime,
      location: _currentLocation,
    );

    await EditHangoutDialog.show(
      context,
      post: currentPost,
      onSave: _handleHangoutUpdate,
    );
  }

  Future<void> _handleHangoutUpdate(
    String newDescription,
    DateTime? newScheduledTime,
    String? newLocation,
  ) async {
    final postProvider = Provider.of<PostProvider>(context, listen: false);

    // Track what changed
    final descriptionChanged = newDescription != _currentDescription;
    final timeChanged = newScheduledTime != _currentScheduledTime;
    final locationChanged = newLocation != _currentLocation;

    if (!descriptionChanged && !timeChanged && !locationChanged) {
      // Nothing changed
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    try {
      // Update the post
      final updatedPost = widget.post.copyWith(
        description: newDescription,
        scheduledTime: newScheduledTime,
        location: newLocation,
      );

      final success = await postProvider.updatePost(updatedPost);

      // Dismiss loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (success && mounted) {
        // Update local state
        setState(() {
          _currentDescription = newDescription;
          _currentScheduledTime = newScheduledTime;
          _currentLocation = newLocation;
        });

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Hangout updated successfully'),
            backgroundColor: AppColors.success,
          ),
        );

        // Build notification message based on what changed
        final changes = <String>[];
        if (descriptionChanged) {
          changes.add('description');
        }
        if (timeChanged) {
          changes.add('time');
        }
        if (locationChanged) {
          changes.add('location');
        }

        // Notify members about the changes
        await _notificationService.notifyHangoutUpdated(
          hangoutId: widget.post.id,
          ownerId: widget.post.authorId,
          participantIds: widget.post.participantIds,
          changes: changes,
          oldDescription: descriptionChanged ? _currentDescription : null,
          oldTime: timeChanged ? _currentScheduledTime : null,
          oldLocation: locationChanged ? _currentLocation : null,
          newDescription: descriptionChanged ? newDescription : null,
          newTime: timeChanged ? newScheduledTime : null,
          newLocation: locationChanged ? newLocation : null,
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(postProvider.error ?? 'Failed to update hangout'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      // Dismiss loading dialog
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  String _formatTimeDisplay(DateTime? scheduledTime) {
    if (scheduledTime == null) {
      return 'No scheduled time';
    }

    if (_isOngoing(scheduledTime)) {
      return 'Ongoing';
    }

    final formatter = DateFormat('MMM d, y \'at\' h:mm a');
    return formatter.format(scheduledTime);
  }

  bool _isOngoing(DateTime? scheduledTime) {
    if (scheduledTime == null) return false;

    final now = DateTime.now();
    final timeDifference = scheduledTime.difference(now);

    // Ongoing if scheduled time was within the last 4 hours
    return timeDifference.inMinutes <= 0 && timeDifference.inMinutes >= -240;
  }

  Future<void> _joinPost(String userId, PostProvider postProvider) async {
    setState(() {
      _isJoiningOrLeaving = true;
    });

    try {
      final success = await postProvider.joinPost(widget.post.id, userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Joined hangout!'
                  : postProvider.error ?? 'Failed to join hangout',
            ),
            backgroundColor: success ? AppColors.success : AppColors.error,
          ),
        );

        // Track hangout join if successful
        if (success) {
          debugPrint('📊 HANGOUT SCREEN - Tracking hangout join analytics');
          debugPrint('📋 User ID: $userId');
          debugPrint('📋 Hangout ID: ${widget.post.id}');

          await AnalyticsService().trackHangoutJoined(
            userId: userId,
            hangoutId: widget.post.id,
          );

          debugPrint('✅ HANGOUT SCREEN - Analytics tracking completed');
        }

        // If successfully joined, manually add user to members list
        if (success) {
          final user = await _firestoreService.getUser(userId);
          if (user != null && mounted) {
            setState(() {
              _members.add(user);
              final authProvider = Provider.of<AuthProvider>(
                context,
                listen: false,
              );
              final currentUserId = authProvider.currentUser?.id;
              if (userId == currentUserId) {
                _currentUserIsParticipant = true;
              }
            });
          }
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isJoiningOrLeaving = false;
        });
      }
    }
  }

  Future<void> _leavePost(String userId) async {
    setState(() {
      _isJoiningOrLeaving = true;
    });

    try {
      final postProvider = Provider.of<PostProvider>(context, listen: false);
      final success = await postProvider.leavePost(widget.post.id, userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Left hangout'
                  : postProvider.error ?? 'Failed to leave hangout',
            ),
            backgroundColor: success ? AppColors.success : AppColors.error,
          ),
        );

        // If successfully left, update local state and navigate back if current user left
        if (success) {
          final authProvider = Provider.of<AuthProvider>(
            context,
            listen: false,
          );
          final currentUserId = authProvider.currentUser?.id;

          setState(() {
            _members.removeWhere((member) => member.id == userId);
            if (userId == currentUserId) {
              _currentUserIsParticipant = false;
            }
            _isJoiningOrLeaving = false;
          });

          // If current user left, navigate back to feed
          if (userId == currentUserId) {
            Navigator.of(context).pop();
          }
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isJoiningOrLeaving = false;
        });
      }
    }
  }
}
