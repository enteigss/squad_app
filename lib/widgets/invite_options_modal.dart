import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import '../services/invite_service.dart';
import '../utils/colors.dart';

class InviteOptionsModal extends StatefulWidget {
  final String hangoutId;
  final String hangoutTitle;
  final String inviterName;

  const InviteOptionsModal({
    super.key,
    required this.hangoutId,
    required this.hangoutTitle,
    required this.inviterName,
  });

  @override
  State<InviteOptionsModal> createState() => _InviteOptionsModalState();

  static Future<void> show(
    BuildContext context, {
    required String hangoutId,
    required String hangoutTitle,
    required String inviterName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => InviteOptionsModal(
        hangoutId: hangoutId,
        hangoutTitle: hangoutTitle,
        inviterName: inviterName,
      ),
    );
  }
}

class _InviteOptionsModalState extends State<InviteOptionsModal> {
  bool _isLoadingContacts = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.4,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Text(
                  'Invite Friends',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'to "${widget.hangoutTitle}"',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Invite options
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  _buildInviteOption(
                    context: context,
                    icon: Icons.sms,
                    title: 'SMS Invite',
                    subtitle: 'Send text message invites to your contacts',
                    onTap: () => _handleSMSInvite(context),
                    isLoading: _isLoadingContacts,
                  ),

                  const SizedBox(height: 16),

                  _buildInviteOption(
                    context: context,
                    icon: Icons.share,
                    title: 'Share Link',
                    subtitle: 'Copy link to share on social media',
                    onTap: () => _handleShareLink(context),
                    isComingSoon: true,
                  ),

                  const SizedBox(height: 16),

                  _buildInviteOption(
                    context: context,
                    icon: Icons.email,
                    title: 'Email Invite',
                    subtitle: 'Send email invitations',
                    onTap: () => _handleEmailInvite(context),
                    isComingSoon: true,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildInviteOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isComingSoon = false,
    bool isLoading = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isComingSoon
            ? AppColors.textSecondary.withOpacity(0.1)
            : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isComingSoon
              ? AppColors.textSecondary.withOpacity(0.2)
              : AppColors.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: ListTile(
        onTap: isComingSoon || isLoading ? null : onTap,
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: isComingSoon || isLoading
                ? AppColors.textSecondary.withOpacity(0.2)
                : AppColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 2,
                  ),
                )
              : Icon(
                  icon,
                  color: isComingSoon
                      ? AppColors.textSecondary
                      : AppColors.primary,
                  size: 24,
                ),
        ),
        title: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isComingSoon
                    ? AppColors.textSecondary
                    : AppColors.textPrimary,
              ),
            ),
            if (isComingSoon) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Coming Soon',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(
          isLoading ? 'Loading contacts...' : subtitle,
          style: TextStyle(
            color: isComingSoon || isLoading
                ? AppColors.textSecondary.withOpacity(0.7)
                : AppColors.textSecondary,
          ),
        ),
        trailing: Icon(
          Icons.chevron_right,
          color: isComingSoon
              ? AppColors.textSecondary.withOpacity(0.5)
              : AppColors.textSecondary,
        ),
      ),
    );
  }

  void _handleSMSInvite(BuildContext context) async {
    print(
      'DEBUG: InviteOptionsModal._handleSMSInvite() - Starting SMS invite flow',
    );

    // Set loading state and close modal
    setState(() {
      _isLoadingContacts = true;
    });

    // Wait a bit to show loading state, then close modal
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) Navigator.of(context).pop();

    try {
      print(
        'DEBUG: InviteOptionsModal._handleSMSInvite() - Calling InviteService.showContactPicker()',
      );
      final selectedContacts = await InviteService.showContactPicker(context);
      print(
        'DEBUG: InviteOptionsModal._handleSMSInvite() - showContactPicker() returned: ${selectedContacts?.length ?? 0} contacts',
      );

      if (selectedContacts != null && selectedContacts.isNotEmpty) {
        print(
          'DEBUG: InviteOptionsModal._handleSMSInvite() - Proceeding to send SMS invites',
        );
        await _sendSMSInvites(context, selectedContacts);
      } else {
        print(
          'DEBUG: InviteOptionsModal._handleSMSInvite() - No contacts selected or null result',
        );
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No contacts selected'),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      }
    } catch (e) {
      print(
        'DEBUG: InviteOptionsModal._handleSMSInvite() - Exception caught: $e',
      );
      if (context.mounted) {
        print('DEBUG: InviteOptionsModal._handleSMSInvite() - Showing error');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      // Reset loading state
      if (mounted) {
        setState(() {
          _isLoadingContacts = false;
        });
      }
    }
  }

  Future<void> _sendSMSInvites(
    BuildContext context,
    List<Contact> contacts,
  ) async {
    try {
      // Show sending progress
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              Text('Sending invites to ${contacts.length} contacts...'),
            ],
          ),
        ),
      );

      // Extract phone numbers
      final phoneNumbers = contacts
          .where((contact) => contact.phones.isNotEmpty)
          .map((contact) => contact.phones.first.number)
          .toList();

      // Send SMS invites
      final result = await InviteService.sendSMSInvites(
        hangoutId: widget.hangoutId,
        phoneNumbers: phoneNumbers,
        inviterName: widget.inviterName,
      );

      // Dismiss progress dialog
      if (context.mounted) Navigator.of(context).pop();

      // Show results
      if (context.mounted) {
        _showInviteResults(context, result, contacts.length);
      }
    } catch (e) {
      // Dismiss progress dialog
      if (context.mounted) Navigator.of(context).pop();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send invites: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showInviteResults(
    BuildContext context,
    SMSInviteResult result,
    int totalContacts,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              result.success ? Icons.check_circle : Icons.error,
              color: result.success ? AppColors.success : AppColors.error,
            ),
            const SizedBox(width: 8),
            Text(result.success ? 'Invites Sent!' : 'Some Invites Failed'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (result.successfulInvites > 0)
              Text('✅ ${result.successfulInvites} invites sent successfully'),
            if (result.failedInvites > 0)
              Text('❌ ${result.failedInvites} invites failed'),
            if (result.errors.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text(
                'Errors:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...result.errors.map(
                (error) =>
                    Text('• $error', style: const TextStyle(fontSize: 12)),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _handleShareLink(BuildContext context) {
    // TODO: Implement share link functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share link feature coming soon!')),
    );
  }

  void _handleEmailInvite(BuildContext context) {
    // TODO: Implement email invite functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Email invite feature coming soon!')),
    );
  }
}
