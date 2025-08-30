import 'package:flutter/material.dart';
import '../utils/colors.dart';

class DeletionFeedbackDialog extends StatefulWidget {
  final String hangoutTitle;
  final VoidCallback onCancel;
  final Function(bool didMeetup, String? additionalFeedback) onConfirmDelete;

  const DeletionFeedbackDialog({
    super.key,
    required this.hangoutTitle,
    required this.onCancel,
    required this.onConfirmDelete,
  });

  static Future<void> show(
    BuildContext context, {
    required String hangoutTitle,
    required VoidCallback onCancel,
    required Function(bool didMeetup, String? additionalFeedback)
    onConfirmDelete,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must respond
      builder: (context) => DeletionFeedbackDialog(
        hangoutTitle: hangoutTitle,
        onCancel: onCancel,
        onConfirmDelete: onConfirmDelete,
      ),
    );
  }

  @override
  State<DeletionFeedbackDialog> createState() => _DeletionFeedbackDialogState();
}

class _DeletionFeedbackDialogState extends State<DeletionFeedbackDialog> {
  final TextEditingController _additionalFeedbackController =
      TextEditingController();

  bool _isSubmitting = false;
  bool? _didMeetup;
  bool _showAdditionalFeedback = false;

  @override
  void dispose() {
    _additionalFeedbackController.dispose();
    super.dispose();
  }

  Future<void> _confirmDelete() async {
    if (_didMeetup == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      widget.onConfirmDelete(
        _didMeetup!,
        _additionalFeedbackController.text.trim().isEmpty
            ? null
            : _additionalFeedbackController.text.trim(),
      );

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
              Icon(Icons.delete_outline, color: AppColors.error, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Delete Hangout?',
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
            'Before deleting, did this hangout actually happen?',
            style: TextStyle(fontSize: 16, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 8),
          Text(
            'This helps us understand how successful our hangouts are.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
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

          // Additional feedback section
          if (_didMeetup != null) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: _showAdditionalFeedback,
                  onChanged: (value) {
                    setState(() {
                      _showAdditionalFeedback = value ?? false;
                    });
                  },
                  activeColor: AppColors.primary,
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _showAdditionalFeedback = !_showAdditionalFeedback;
                      });
                    },
                    child: Text(
                      'Add additional feedback (optional)',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            if (_showAdditionalFeedback) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _additionalFeedbackController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: _didMeetup!
                      ? 'Tell us what made this hangout great...'
                      : 'What could we improve for next time?',
                  hintStyle: TextStyle(
                    color: AppColors.textSecondary.withOpacity(0.7),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: AppColors.primary.withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                  contentPadding: const EdgeInsets.all(12),
                ),
              ),
            ],
          ],
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

        // Delete button
        ElevatedButton(
          onPressed: (_didMeetup != null && !_isSubmitting)
              ? _confirmDelete
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
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
              : const Text('Delete Hangout'),
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
