import 'package:flutter/material.dart';
import '../utils/colors.dart';

class MeetupOutcomeDialog extends StatefulWidget {
  final VoidCallback? onCancel;
  final Function(bool didMeetup) onConfirmDelete;
  final String? contextText;
  final String? actionButtonText;
  final IconData? headerIcon;
  final Color? headerColor;
  final bool isRequired;

  const MeetupOutcomeDialog({
    super.key,
    this.onCancel,
    required this.onConfirmDelete,
    this.contextText,
    this.actionButtonText,
    this.headerIcon,
    this.headerColor,
    this.isRequired = false,
  });

  static Future<void> show(
    BuildContext context, {
    VoidCallback? onCancel,
    required Function(bool didMeetup) onConfirmDelete,
    String? contextText,
    String? actionButtonText,
    IconData? headerIcon,
    Color? headerColor,
    bool isRequired = false,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: !isRequired, // Required dialogs can't be dismissed by tapping outside
      builder: (context) => PopScope(
        canPop: !isRequired, // Required dialogs can't be dismissed with back button
        child: MeetupOutcomeDialog(
          onCancel: onCancel,
          onConfirmDelete: onConfirmDelete,
          contextText: contextText,
          actionButtonText: actionButtonText,
          headerIcon: headerIcon,
          headerColor: headerColor,
          isRequired: isRequired,
        ),
      ),
    );
  }

  @override
  State<MeetupOutcomeDialog> createState() => _MeetupOutcomeDialogState();
}

class _MeetupOutcomeDialogState extends State<MeetupOutcomeDialog> {
  bool _isSubmitting = false;
  bool? _didMeetup;

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _confirmDelete() async {
    if (_didMeetup == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      widget.onConfirmDelete(_didMeetup!);

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to delete hangout. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.all(24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                widget.headerIcon ?? Icons.delete_outline, 
                color: widget.headerColor ?? AppColors.error, 
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.contextText ?? 'Delete Hangout?',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Hangout title
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: (widget.headerColor ?? AppColors.error).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: (widget.headerColor ?? AppColors.error).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.event, color: widget.headerColor ?? AppColors.error, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Hangout',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Required indicator (if applicable)
          if (widget.isRequired) ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.primary, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'This feedback is required to help us improve the app.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Main question
          Text(
            'Did this hangout actually happen?',
            style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 16),

          // Yes/No buttons
          Row(
            children: [
              Expanded(
                child: _buildResponseButton(
                  text: 'Yes, we met up! 🎉',
                  value: true,
                  color: AppColors.success,
                  icon: Icons.check_circle_outline,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildResponseButton(
                  text: 'No, we didn\'t meet',
                  value: false,
                  color: AppColors.error,
                  icon: Icons.cancel_outlined,
                ),
              ),
            ],
          ),

        ],
      ),
      actions: [
        // Cancel button (only show if not required and onCancel is provided)
        if (!widget.isRequired && widget.onCancel != null)
          TextButton(
            onPressed: _isSubmitting
                ? null
                : () {
                    Navigator.of(context).pop();
                    widget.onCancel!();
                  },
            child: Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),

        // Action button
        ElevatedButton(
          onPressed: (_didMeetup != null && !_isSubmitting)
              ? _confirmDelete
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.headerColor ?? AppColors.error,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(widget.actionButtonText ?? 'Delete Hangout'),
        ),
      ],
    );
  }

  Widget _buildResponseButton({
    required String text,
    required bool value,
    required Color color,
    required IconData icon,
  }) {
    final isSelected = _didMeetup == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _didMeetup = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? color
                : AppColors.textSecondary.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? color : AppColors.textSecondary,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? color : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
