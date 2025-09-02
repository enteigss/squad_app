import 'package:flutter/material.dart';
import '../utils/colors.dart';

class MeetupOutcomeDialog extends StatefulWidget {
  final String hangoutTitle;
  final VoidCallback onCancel;
  final Function(bool didMeetup) onConfirmDelete;
  final String? contextText;
  final String? actionButtonText;
  final IconData? headerIcon;
  final Color? headerColor;

  const MeetupOutcomeDialog({
    super.key,
    required this.hangoutTitle,
    required this.onCancel,
    required this.onConfirmDelete,
    this.contextText,
    this.actionButtonText,
    this.headerIcon,
    this.headerColor,
  });

  static Future<void> show(
    BuildContext context, {
    required String hangoutTitle,
    required VoidCallback onCancel,
    required Function(bool didMeetup) onConfirmDelete,
    String? contextText,
    String? actionButtonText,
    IconData? headerIcon,
    Color? headerColor,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must respond
      builder: (context) => MeetupOutcomeDialog(
        hangoutTitle: hangoutTitle,
        onCancel: onCancel,
        onConfirmDelete: onConfirmDelete,
        contextText: contextText,
        actionButtonText: actionButtonText,
        headerIcon: headerIcon,
        headerColor: headerColor,
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
              color: AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.error.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.event, color: AppColors.error, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.hangoutTitle,
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
        // Cancel button
        TextButton(
          onPressed: _isSubmitting
              ? null
              : () {
                  Navigator.of(context).pop();
                  widget.onCancel();
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
          color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? color
                : AppColors.textSecondary.withOpacity(0.3),
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
