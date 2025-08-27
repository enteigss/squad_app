import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../utils/colors.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class SquadsInterestScreen extends StatefulWidget {
  const SquadsInterestScreen({super.key});

  @override
  State<SquadsInterestScreen> createState() => _SquadsInterestScreenState();
}

class _SquadsInterestScreenState extends State<SquadsInterestScreen> {
  bool _hasResponded = false;
  bool? _currentInterest;
  DateTime? _lastSubmittedAt;
  bool _isSubmitting = false;
  String? _feedbackText;
  final _feedbackController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkUserResponse();
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _checkUserResponse() async {
    try {
      final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;
      
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.id)
            .get();
        
        if (doc.exists && mounted) {
          final data = doc.data()!;
          final hasResponded = data['squadsInterestSubmittedAt'] != null;
          final interest = data['squadsInterest'] as bool?;
          final feedback = data['squadsInterestFeedback'] as String?;
          final submittedAt = data['squadsInterestSubmittedAt'] as Timestamp?;
          
          setState(() {
            _hasResponded = hasResponded;
            _currentInterest = interest;
            _lastSubmittedAt = submittedAt?.toDate();
            if (feedback != null) {
              _feedbackText = feedback;
              _feedbackController.text = feedback;
            }
          });
        }
      }
    } catch (e) {
      debugPrint('Error checking user response: $e');
    }
  }

  Future<void> _submitInterestResponse(bool isInterested) async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final authProvider = Provider.of<app_auth.AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;
      
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.id)
            .update({
          'squadsInterest': isInterested,
          'squadsInterestFeedback': _feedbackText?.trim().isNotEmpty == true ? _feedbackText!.trim() : null,
          'squadsInterestSubmittedAt': FieldValue.serverTimestamp(),
        });

        setState(() {
          _hasResponded = true;
          _currentInterest = isInterested;
          _lastSubmittedAt = DateTime.now();
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_hasResponded ? 'Your response has been updated!' : 'Thank you for your feedback!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit response: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Squads'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Consumer<app_auth.AuthProvider>(
        builder: (context, authProvider, child) {
          final user = authProvider.currentUser;
          if (user == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildInterestSurvey(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInterestSurvey() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Current status display if user has responded
        if (_hasResponded) _buildCurrentStatusCard(),
        if (_hasResponded) const SizedBox(height: 20),
        
        // Main question
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.group, color: AppColors.primary, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Would you be interested in using a Squads feature?',
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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.construction, color: AppColors.primary, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Squads is currently in development - we\'re gauging interest!',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Explanation section
        _buildSquadExplanation(),

        const SizedBox(height: 20),

        // Feedback text field
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Any additional thoughts? (Optional)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              CustomTextField(
                controller: _feedbackController,
                hint: 'Share your thoughts on the squads concept...',
                maxLines: 3,
                onChanged: (value) {
                  _feedbackText = value;
                },
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // Response buttons
        Row(
          children: [
            Expanded(
              child: CustomButton(
                text: _isSubmitting ? 'Updating...' : 'Yes, I\'m interested',
                onPressed: _isSubmitting ? null : () => _submitInterestResponse(true),
                backgroundColor: _currentInterest == true ? AppColors.primary : AppColors.success,
                isLoading: _isSubmitting,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: CustomButton(
                text: _isSubmitting ? 'Updating...' : 'Not interested',
                onPressed: _isSubmitting ? null : () => _submitInterestResponse(false),
                backgroundColor: _currentInterest == false ? AppColors.primary : AppColors.textSecondary,
                isLoading: _isSubmitting,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSquadExplanation() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What is Squads?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildSquadInfoSection(
            icon: Icons.group,
            title: 'Squad Formation',
            description: 'Squads would be formed automatically based on your compatibility preferences and matching criteria.',
          ),
          const SizedBox(height: 12),
          _buildSquadInfoSection(
            icon: Icons.people_alt,
            title: 'Party Pack System',
            description: 'Designate a party pack partner to be matched together in the same squad.',
          ),
          const SizedBox(height: 12),
          _buildSquadInfoSection(
            icon: Icons.chat,
            title: 'Squad Chat',
            description: 'Once in a squad, you could chat with your squad members and plan activities together.',
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStatusCard() {
    final isInterested = _currentInterest == true;
    final statusText = isInterested ? 'interested' : 'not interested';
    final statusColor = isInterested ? AppColors.success : AppColors.textSecondary;
    final statusIcon = isInterested ? Icons.thumb_up : Icons.thumb_down;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(statusIcon, color: statusColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You are currently $statusText in Squads',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (_lastSubmittedAt != null)
                  Text(
                    'Last updated: ${_formatDateTime(_lastSubmittedAt!)}',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          Icon(
            Icons.edit,
            color: AppColors.primary,
            size: 20,
          ),
        ],
      ),
    );
  }
  
  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }

  Widget _buildSquadInfoSection({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}