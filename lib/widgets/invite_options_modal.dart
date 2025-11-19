import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/colors.dart';
import '../config/environment.dart';

class InviteOptionsModal extends StatefulWidget {
  final String hangoutId;
  final String inviterName;

  const InviteOptionsModal({
    super.key,
    required this.hangoutId,
    required this.inviterName,
  });

  @override
  State<InviteOptionsModal> createState() => _InviteOptionsModalState();

  static Future<void> show(
    BuildContext context, {
    required String hangoutId,
    required String inviterName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => InviteOptionsModal(
        hangoutId: hangoutId,
        inviterName: inviterName,
      ),
    );
  }
}

class _InviteOptionsModalState extends State<InviteOptionsModal> {

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
                  'to this hangout',
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
                    icon: Icons.share,
                    title: 'Share Link',
                    subtitle: 'Share via messages, social media, or any app',
                    onTap: () => _handleShareLink(context),
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


  void _handleShareLink(BuildContext context) async {
    print('DEBUG: _handleShareLink() called');
    try {
      // Generate the invite URL using environment-specific web app URL
      final shareUrl =
          '${EnvironmentConfig.webAppUrl}/hangout/${widget.hangoutId}';
      final shareText = 'Join me for this hangout! $shareUrl';

      // Get the box position BEFORE closing the modal
      print('DEBUG: Getting render box position');
      final box = context.findRenderObject() as RenderBox?;
      final sharePositionOrigin = box != null
          ? box.localToGlobal(Offset.zero) & box.size
          : null;

      // Close the modal first
      print('DEBUG: Closing InviteOptionsModal with result "completed"');
      Navigator.of(context).pop('completed');

      // Add a small delay to ensure modal is closed before sharing
      await Future.delayed(const Duration(milliseconds: 200));
      print('DEBUG: About to open native share dialog');

      // Try native sharing first, fallback to clipboard
      try {
        print('DEBUG: Calling Share.share()');
        await Share.share(
          shareText,
          subject: 'You\'re invited to a hangout',
          sharePositionOrigin: sharePositionOrigin,
        );
        print('DEBUG: Share.share() completed');
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

}
