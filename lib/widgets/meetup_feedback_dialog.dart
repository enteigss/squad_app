import 'package:flutter/material.dart';
import '../utils/colors.dart';
import '../models/meetup_feedback.dart';
import '../services/feedback_service.dart';
import '../services/analytics_service.dart';

class MeetupFeedbackDialog extends StatefulWidget {
  final PendingFeedbackPrompt prompt;
  final VoidCallback? onFeedbackSubmitted;

  const MeetupFeedbackDialog({
    super.key,
    required this.prompt,
    this.onFeedbackSubmitted,
  });

  static Future<void> show(
    BuildContext context, {
    required PendingFeedbackPrompt prompt,
    VoidCallback? onFeedbackSubmitted,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must respond
      builder: (context) => MeetupFeedbackDialog(
        prompt: prompt,
        onFeedbackSubmitted: onFeedbackSubmitted,
      ),
    );
  }

  @override
  State<MeetupFeedbackDialog> createState() => _MeetupFeedbackDialogState();
}

class _MeetupFeedbackDialogState extends State<MeetupFeedbackDialog> {
  final FeedbackService _feedbackService = FeedbackService();
  final TextEditingController _additionalFeedbackController = TextEditingController();
  
  bool _isSubmitting = false;
  bool? _didMeetup;
  bool _showAdditionalFeedback = false;

  @override
  void dispose() {
    _additionalFeedbackController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (_didMeetup == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      await _feedbackService.submitFeedback(
        hangoutId: widget.prompt.hangoutId,
        userId: widget.prompt.userId,
        hangoutTitle: widget.prompt.hangoutTitle,
        didMeetup: _didMeetup!,
        additionalFeedback: _additionalFeedbackController.text.trim().isEmpty 
            ? null 
            : _additionalFeedbackController.text.trim(),
      );

      // Track the feedback submission in analytics
      await AnalyticsService().trackMeetupFeedbackSubmitted(
        hangoutId: widget.prompt.hangoutId,
        didMeetup: _didMeetup!,
        hasAdditionalFeedback: _additionalFeedbackController.text.trim().isNotEmpty,
      );

      // Note: Don't mark as shown here since submitFeedback will handle the cleanup

      if (mounted) {
        Navigator.of(context).pop();
        widget.onFeedbackSubmitted?.call();
        
        // Show a thank you message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _didMeetup! 
                  ? 'Thanks for the feedback! Glad your hangout was successful! 🎉'
                  : 'Thanks for the feedback! We\'ll work on improving the experience.',
            ),
            backgroundColor: _didMeetup! ? AppColors.success : AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to submit feedback. Please try again.'),
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
                Icons.feedback_outlined,
                color: AppColors.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'How did it go?',
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
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.event,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.prompt.hangoutTitle,
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
            'Did you and the other participants actually meet up for this hangout?',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textPrimary,
            ),
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
                  hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.7)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.primary.withOpacity(0.3)),
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
        // Skip button (only if no response selected yet)
        if (_didMeetup == null)
          TextButton(
            onPressed: () async {
              // Just close the dialog - we'll let the prompt stay for later
              if (mounted) {
                Navigator.of(context).pop();
              }
            },
            child: Text(
              'Skip for now',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),

        // Submit button
        if (_didMeetup != null)
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submitFeedback,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
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
                : const Text('Submit Feedback'),
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
            color: isSelected ? color : AppColors.textSecondary.withOpacity(0.3),
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