import 'package:flutter/material.dart';
import '../models/report_model.dart';
import '../utils/colors.dart';

class ReportDialog extends StatefulWidget {
  final String contentType;
  final String contentId;
  final String contentTitle;
  final String authorId;
  final Map<String, dynamic> contentSnippet;
  final Function(ReportReason reason) onSubmit;

  const ReportDialog({
    super.key,
    required this.contentType,
    required this.contentId,
    required this.contentTitle,
    required this.authorId,
    required this.contentSnippet,
    required this.onSubmit,
  });

  static Future<void> show(
    BuildContext context, {
    required String contentType,
    required String contentId,
    required String contentTitle,
    required String authorId,
    required Map<String, dynamic> contentSnippet,
    required Function(ReportReason reason) onSubmit,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => ReportDialog(
        contentType: contentType,
        contentId: contentId,
        contentTitle: contentTitle,
        authorId: authorId,
        contentSnippet: contentSnippet,
        onSubmit: onSubmit,
      ),
    );
  }

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  ReportReason? _selectedReason;
  bool _isSubmitting = false;

  Future<void> _submitReport() async {
    if (_selectedReason == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      widget.onSubmit(_selectedReason!);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit report: $e'),
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
              Icon(Icons.flag_outlined, color: AppColors.error, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Report ${widget.contentType == 'hangout' ? 'Hangout' : 'Content'}',
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

          // Content info
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
                Icon(
                  widget.contentType == 'hangout' ? Icons.event : Icons.content_copy,
                  color: AppColors.error,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.contentTitle,
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

          // Report reason selection
          Text(
            'Please select a reason for reporting:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          // Reason options
          ...ReportReason.values.map((reason) => _buildReasonOption(reason)),

          if (_selectedReason == null) ...[
            const SizedBox(height: 8),
            Text(
              '* Please select a reason to continue',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.error,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          const SizedBox(height: 16),

        ],
      ),
      actions: [
        // Cancel button
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),

        // Submit button
        ElevatedButton(
          onPressed: (_selectedReason != null && !_isSubmitting) ? _submitReport : null,
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
              : const Text('Submit Report'),
        ),
      ],
    );
  }

  Widget _buildReasonOption(ReportReason reason) {
    final isSelected = _selectedReason == reason;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedReason = reason;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected 
                ? AppColors.primary.withOpacity(0.1) 
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected 
                  ? AppColors.primary 
                  : AppColors.textSecondary.withOpacity(0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Radio<ReportReason>(
                value: reason,
                groupValue: _selectedReason,
                onChanged: (ReportReason? value) {
                  setState(() {
                    _selectedReason = value;
                  });
                },
                activeColor: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  reason.displayName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected 
                        ? AppColors.primary 
                        : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}