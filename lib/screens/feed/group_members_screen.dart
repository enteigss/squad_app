import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/post_model.dart';
import '../../models/user_model.dart';
import '../../models/report_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/post_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/report_service.dart';
import '../../utils/colors.dart';
import 'post_chat_screen.dart';
import '../profile/profile_detail_screen.dart';
import '../../widgets/invite_options_modal.dart';
import '../../widgets/report_dialog.dart';

class GroupMembersScreen extends StatefulWidget {
  final Post post;
  final bool isParticipant;

  const GroupMembersScreen({
    super.key,
    required this.post,
    this.isParticipant = true, // Default to true for backward compatibility
  });

  @override
  State<GroupMembersScreen> createState() => _GroupMembersScreenState();
}

class _GroupMembersScreenState extends State<GroupMembersScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final ReportService _reportService = ReportService();
  final TextEditingController _descriptionController = TextEditingController();
  List<UserModel> _members = [];
  bool _isLoading = true;
  bool _isEditingDescription = false;
  String _currentDescription = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _currentDescription = widget.post.description;
    _descriptionController.text = widget.post.description;
    _loadGroupMembers();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadGroupMembers() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final members = <UserModel>[];

      // Load each participant's user data
      for (final participantId in widget.post.participantIds) {
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
    final bool isGroupFull =
        widget.post.participantIds.length >= (widget.post.maxParticipants);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            // Use stack navigation to pop back to previous screen
            Navigator.of(context).pop();
          },
        ),
        title: Text(
          widget.isParticipant
              ? 'Group Members (${widget.post.participantIds.length})'
              : 'Group Preview (${widget.post.participantIds.length})',
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
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
                Text(
                  widget.post.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                _buildDescriptionSection(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.people,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${widget.post.participantIds.length} members',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Preview notice for non-participants
          if (!widget.isParticipant)
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
      bottomNavigationBar: widget.isParticipant
          ? _buildBottomActions(isGroupFull)
          : null,
    );
  }

  Widget _buildBottomActions(bool isGroupFull) {
    final bool showInvite = !isGroupFull;
    final bool showChat = true; // Always show chat for participants

    return Container(
      padding: const EdgeInsets.fromLTRB(
        16,
        12,
        16,
        24,
      ), // Added extra bottom padding for safe area
      color: AppColors.background, // Match scaffold background
      child: showInvite && showChat
          ? Row(
              children: [
                // Group Chat button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _openChat,
                    icon: const Icon(Icons.chat, size: 18),
                    label: const Text('Group Chat'),
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
                ),
                const SizedBox(width: 12),
                // Invite Friends button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _openInviteModal,
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('Invite Friends'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            )
          : showChat
              ? ElevatedButton.icon(
                  onPressed: _openChat,
                  icon: const Icon(Icons.chat, size: 18),
                  label: const Text('Group Chat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                )
              : ElevatedButton.icon(
                  onPressed: _openInviteModal,
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Invite Friends'),
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
  void _openInviteModal() {
    // Get the current user's name from AuthProvider
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final inviterName = authProvider.currentUser?.displayName ?? 'A friend';

    // This assumes you have an InviteOptionsModal with a static `show` method.
    // The Navigator.pop() call from your example is removed as it's not needed here.
    InviteOptionsModal.show(
      context,
      hangoutId: widget.post.id,
      hangoutTitle: widget.post.title,
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
        return _buildMemberCard(_members[index]);
      },
    );
  }

  Widget _buildMemberCard(UserModel member) {
    final currentUserId = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).currentUser?.id;
    final isCurrentUser = member.id == currentUserId;
    final isAuthor = member.id == widget.post.authorId;

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
              // Profile picture placeholder
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                backgroundImage: member.photoUrl != null
                    ? NetworkImage(member.photoUrl!)
                    : null,
                child: member.photoUrl == null
                    ? Icon(Icons.person, color: AppColors.primary, size: 24)
                    : null,
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
    if (!widget.isParticipant) return false;

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

  void _openChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostChatScreen(post: widget.post),
      ),
    );
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
        contentTitle: widget.post.title,
        authorId: widget.post.authorId,
        contentSnippet: ReportService.createHangoutContentSnippet(
          title: widget.post.title,
          description: widget.post.description,
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
        contentType: 'hangout',
        contentId: widget.post.id,
        contentTitle: widget.post.title,
        authorId: widget.post.authorId,
        contentSnippet: ReportService.createHangoutContentSnippet(
          title: widget.post.title,
          description: widget.post.description,
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
            content: Text('Report submitted successfully. Thank you for helping keep our community safe.'),
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

  Widget _buildDescriptionSection() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.id;
    final isAuthor = currentUserId == widget.post.authorId;

    if (_isEditingDescription && isAuthor) {
      return _buildDescriptionEditor();
    }

    return _buildDescriptionDisplay(isAuthor);
  }

  Widget _buildDescriptionDisplay(bool isAuthor) {
    final hasDescription = _currentDescription.isNotEmpty;
    
    return Row(
      children: [
        Expanded(
          child: hasDescription
              ? Text(
                  _currentDescription,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                )
              : isAuthor
                  ? Text(
                      'Add description',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary.withValues(alpha: 0.7),
                        fontStyle: FontStyle.italic,
                      ),
                    )
                  : const SizedBox.shrink(),
        ),
        if (isAuthor) ...[
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _startEditingDescription,
            child: Icon(
              Icons.edit,
              size: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDescriptionEditor() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _descriptionController,
          maxLines: null,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: 'Enter description...',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.textSecondary.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: AppColors.primary),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          autofocus: true,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            GestureDetector(
              onTap: _cancelEditing,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.close, size: 14, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      'Cancel',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _saveDescription,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    const Text(
                      'Save',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _startEditingDescription() {
    setState(() {
      _isEditingDescription = true;
    });
  }

  void _cancelEditing() {
    setState(() {
      _descriptionController.text = _currentDescription;
      _isEditingDescription = false;
    });
  }

  Future<void> _saveDescription() async {
    final newDescription = _descriptionController.text.trim();
    final postProvider = Provider.of<PostProvider>(context, listen: false);
    
    try {
      final updatedPost = widget.post.copyWith(description: newDescription);
      final success = await postProvider.updatePost(updatedPost);
      
      if (success && mounted) {
        setState(() {
          _currentDescription = newDescription;
          _isEditingDescription = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newDescription.isEmpty ? 'Description removed' : 'Description updated'),
            backgroundColor: AppColors.success,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(postProvider.error ?? 'Failed to update description'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }
}
