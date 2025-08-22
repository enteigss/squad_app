import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:share_plus/share_plus.dart';
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
                    subtitle: 'Share via messages, social media, or any app',
                    onTap: () => _handleShareLink(context),
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

    // Capture the parent context before popping this modal
    final parentContext = Navigator.of(context, rootNavigator: true).context;
    print(
      'DEBUG: InviteOptionsModal._handleSMSInvite() - Captured parent context',
    );

    // Set loading state and close modal
    setState(() {
      _isLoadingContacts = true;
    });

    // Wait a bit to show loading state, then close modal
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) Navigator.of(context).pop();

    // Add delay to ensure modal is fully closed
    await Future.delayed(const Duration(milliseconds: 200));

    try {
      print(
        'DEBUG: InviteOptionsModal._handleSMSInvite() - Calling InviteService.showContactPicker() with parent context',
      );
      final selectedContacts = await InviteService.showContactPicker(
        parentContext,
      );
      print(
        'DEBUG: InviteOptionsModal._handleSMSInvite() - showContactPicker() returned: ${selectedContacts?.length ?? 0} contacts',
      );

      if (selectedContacts != null && selectedContacts.isNotEmpty) {
        print(
          'DEBUG: InviteOptionsModal._handleSMSInvite() - Proceeding to send SMS invites with parent context',
        );
        await _sendSMSInvites(parentContext, selectedContacts);
      } else {
        print(
          'DEBUG: InviteOptionsModal._handleSMSInvite() - No contacts selected or null result',
        );
        try {
          ScaffoldMessenger.of(parentContext).showSnackBar(
            const SnackBar(
              content: Text('No contacts selected'),
              backgroundColor: AppColors.primary,
            ),
          );
        } catch (snackbarError) {
          print(
            'DEBUG: InviteOptionsModal._handleSMSInvite() - Could not show snackbar: $snackbarError',
          );
        }
      }
    } catch (e) {
      print(
        'DEBUG: InviteOptionsModal._handleSMSInvite() - Exception caught: $e',
      );
      try {
        print(
          'DEBUG: InviteOptionsModal._handleSMSInvite() - Showing error with parent context',
        );
        ScaffoldMessenger.of(parentContext).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      } catch (snackbarError) {
        print(
          'DEBUG: InviteOptionsModal._handleSMSInvite() - Could not show error snackbar: $snackbarError',
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
    print('📱 DEBUG: _sendSMSInvites() - Starting SMS invite process');
    print(
      '👥 DEBUG: _sendSMSInvites() - Contacts to send to: ${contacts.length}',
    );
    print('🏷️ DEBUG: _sendSMSInvites() - Hangout ID: ${widget.hangoutId}');
    print('👤 DEBUG: _sendSMSInvites() - Inviter name: ${widget.inviterName}');

    try {
      print(
        '💬 DEBUG: _sendSMSInvites() - Checking context validity before showing progress dialog',
      );

      // Check if context is still valid before showing dialog
      if (!context.mounted) {
        print(
          '❌ DEBUG: _sendSMSInvites() - Context not mounted, cannot show progress dialog',
        );
        throw Exception('Context is no longer valid');
      }

      print(
        '✅ DEBUG: _sendSMSInvites() - Context is valid, showing progress dialog',
      );

      // Add small delay to ensure previous navigation is complete
      await Future.delayed(const Duration(milliseconds: 100));

      // Double-check context is still valid after delay
      if (!context.mounted) {
        print(
          '❌ DEBUG: _sendSMSInvites() - Context became invalid during delay',
        );
        throw Exception('Context became invalid');
      }

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

      print(
        '📞 DEBUG: _sendSMSInvites() - Extracting phone numbers from contacts',
      );

      // Extract phone numbers
      final phoneNumbers = contacts
          .where((contact) => contact.phones.isNotEmpty)
          .map((contact) => contact.phones.first.number)
          .toList();

      print(
        '📋 DEBUG: _sendSMSInvites() - Extracted phone numbers: $phoneNumbers',
      );
      print(
        '🔢 DEBUG: _sendSMSInvites() - Phone numbers count: ${phoneNumbers.length}',
      );

      if (phoneNumbers.isEmpty) {
        print(
          '⚠️ DEBUG: _sendSMSInvites() - No phone numbers found in contacts',
        );
        throw Exception('No phone numbers found in selected contacts');
      }

      print(
        '🚀 DEBUG: _sendSMSInvites() - Calling InviteService.sendSMSInvites',
      );

      // Send SMS invites
      final result = await InviteService.sendSMSInvites(
        hangoutId: widget.hangoutId,
        phoneNumbers: phoneNumbers,
        inviterName: widget.inviterName,
      );

      print('✅ DEBUG: _sendSMSInvites() - InviteService call completed');
      print(
        '📊 DEBUG: _sendSMSInvites() - Result: ${result.success ? "SUCCESS" : "FAILED"}',
      );
      print(
        '📊 DEBUG: _sendSMSInvites() - Successful: ${result.successfulInvites}, Failed: ${result.failedInvites}',
      );
      print('❌ DEBUG: _sendSMSInvites() - Errors: ${result.errors}');

      // Dismiss progress dialog
      print('🔄 DEBUG: _sendSMSInvites() - Dismissing progress dialog');
      if (context.mounted) Navigator.of(context).pop();

      // Show results
      print('📋 DEBUG: _sendSMSInvites() - Showing results to user');
      if (context.mounted) {
        _showInviteResults(context, result, contacts.length);
      }

      print(
        '🎉 DEBUG: _sendSMSInvites() - SMS invite process completed successfully',
      );
    } catch (e) {
      print('💥 DEBUG: _sendSMSInvites() - Exception caught: $e');
      print('📍 DEBUG: _sendSMSInvites() - Exception type: ${e.runtimeType}');

      // Dismiss progress dialog
      print(
        '🔄 DEBUG: _sendSMSInvites() - Dismissing progress dialog after error',
      );
      if (context.mounted) Navigator.of(context).pop();

      print('📱 DEBUG: _sendSMSInvites() - Showing error snackbar');
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

  void _handleShareLink(BuildContext context) async {
    try {
      // Generate the invite URL
      final shareUrl =
          'https://squad-7bc7e.web.app/hangout/${widget.hangoutId}';
      final shareText = 'Join me for "${widget.hangoutTitle}"! $shareUrl';

      // Close the modal first
      Navigator.of(context).pop();

      // Add a small delay to ensure modal is closed before sharing
      await Future.delayed(const Duration(milliseconds: 200));

      // Try native sharing first, fallback to clipboard
      try {
        await SharePlus.instance.share(
          ShareParams(
            text: shareText,
            subject: 'You\'re invited to ${widget.hangoutTitle}',
          ),
        );
      } catch (shareError) {
        print('Native share failed, using clipboard fallback: $shareError');

        // Fallback: Copy to clipboard
        await Clipboard.setData(ClipboardData(text: shareText));

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invite link copied to clipboard! 📋'),
              backgroundColor: AppColors.primary,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('Error sharing: $e');
      // Show error if everything fails
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error sharing link. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _handleEmailInvite(BuildContext context) {
    // TODO: Implement email invite functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Email invite feature coming soon!')),
    );
  }
}
