import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/matching_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/colors.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/rating_button_row.dart';

class QuestionnaireScreen extends StatefulWidget {
  final VoidCallback onComplete;
  final VoidCallback onCancel;

  const QuestionnaireScreen({
    super.key,
    required this.onComplete,
    required this.onCancel,
  });

  @override
  State<QuestionnaireScreen> createState() => _QuestionnaireScreenState();
}

class _QuestionnaireScreenState extends State<QuestionnaireScreen> {
  late PageController _pageController;
  final TextEditingController _funActivitiesController = TextEditingController();
  final TextEditingController _talkAboutController = TextEditingController();
  final TextEditingController _freeTimeController = TextEditingController();
  final TextEditingController _elaborationController = TextEditingController();
  final TextEditingController _friendTypeController = TextEditingController();
  final TextEditingController _friendTypeMatchWellController = TextEditingController();
  final TextEditingController _friendTypeNoMatchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _pageController = PageController();

    // Initialize text controllers with existing values
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final matchingProvider = Provider.of<MatchingProvider>(context, listen: false);
      _funActivitiesController.text = matchingProvider.funActivities;
      _talkAboutController.text = matchingProvider.talkAboutForever;
      _freeTimeController.text = matchingProvider.freeTime;
      _elaborationController.text = matchingProvider.activityPreferencesElaboration;
      _friendTypeController.text = matchingProvider.friendType;
      _friendTypeMatchWellController.text = matchingProvider.friendTypeMatchWell;
      _friendTypeNoMatchController.text = matchingProvider.friendTypeNoMatch;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _funActivitiesController.dispose();
    _talkAboutController.dispose();
    _freeTimeController.dispose();
    _elaborationController.dispose();
    _friendTypeController.dispose();
    _friendTypeMatchWellController.dispose();
    _friendTypeNoMatchController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _handleSubmit() async {
    final matchingProvider = Provider.of<MatchingProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    matchingProvider.setSubmitting(true);

    try {
      final profile = matchingProvider.buildProfile();
      await authProvider.updateMatchingProfile(profile);
      widget.onComplete();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save profile: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      matchingProvider.setSubmitting(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Connect Questionnaire'),
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _showExitConfirmation(context),
        ),
      ),
      body: Consumer<MatchingProvider>(
        builder: (context, matchingProvider, child) {
          return Column(
            children: [
              // Progress indicator
              _buildProgressIndicator(matchingProvider),
              // Question pages
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) {
                    matchingProvider.goToQuestion(index);
                  },
                  children: [
                    _buildGenderPreferencePage(matchingProvider),
                    _buildFunActivitiesPage(matchingProvider),
                    _buildTalkAboutPage(matchingProvider),
                    _buildFreeTimePage(matchingProvider),
                    _buildRatingPage(
                      matchingProvider,
                      'deepConversations',
                      'How much do you enjoy deep conversations?',
                      'Having meaningful, intellectual discussions about life, ideas, and everything in between.',
                      matchingProvider.deepConversationsRating,
                    ),
                    _buildRatingPage(
                      matchingProvider,
                      'outdoors',
                      'How much do you enjoy outdoor activities?',
                      'Things like hiking, walking, camping, or just being outside in nature.',
                      matchingProvider.outdoorsRating,
                    ),
                    _buildRatingPage(
                      matchingProvider,
                      'chilling',
                      'How much do you enjoy just chilling?',
                      'Relaxing indoors, playing games, scrolling phones, or just hanging out without needing to talk much.',
                      matchingProvider.chillingRating,
                    ),
                    _buildRatingPage(
                      matchingProvider,
                      'competitiveGames',
                      'How much do you enjoy competitive games?',
                      'Video games, board games, mini golf, pool, or anything with a bit of friendly competition.',
                      matchingProvider.competitiveGamesRating,
                    ),
                    _buildRatingPage(
                      matchingProvider,
                      'meals',
                      'How much do you enjoy grabbing a meal?',
                      'Going out to eat, trying new restaurants, or just sharing food with friends.',
                      matchingProvider.mealsRating,
                    ),
                    _buildRatingPage(
                      matchingProvider,
                      'nightsOut',
                      'How much do you enjoy nights out?',
                      'Parties, clubs, bars, or any kind of nightlife activities.',
                      matchingProvider.nightsOutRating,
                    ),
                    _buildElaborationPage(matchingProvider),
                    _buildFriendTypePage(matchingProvider),
                  ],
                ),
              ),
              // Navigation buttons
              _buildNavigationButtons(matchingProvider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildProgressIndicator(MatchingProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${provider.currentQuestionIndex + 1} of ${provider.totalQuestions}',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              Text(
                '${((provider.currentQuestionIndex + 1) / provider.totalQuestions * 100).round()}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: (provider.currentQuestionIndex + 1) / provider.totalQuestions,
            backgroundColor: AppColors.divider,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderPreferencePage(MatchingProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Who are you looking to be friends with?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This helps us match you with people you\'d be comfortable hanging out with.',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          _buildGenderOption(
            provider,
            'Anyone',
            'I\'m open to connecting with anyone',
            Icons.groups_outlined,
          ),
          const SizedBox(height: 12),
          _buildGenderOption(
            provider,
            'Women',
            'I prefer connecting with women',
            Icons.woman_outlined,
          ),
          const SizedBox(height: 12),
          _buildGenderOption(
            provider,
            'Men',
            'I prefer connecting with men',
            Icons.man_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildGenderOption(
    MatchingProvider provider,
    String value,
    String description,
    IconData icon,
  ) {
    final isSelected = provider.genderPreference == value;

    return GestureDetector(
      onTap: () => provider.setGenderPreference(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withValues(alpha: 0.1) : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.2)
                    : AppColors.divider.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: AppColors.primary,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFunActivitiesPage(MatchingProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What do you like to do for fun?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tell us about your hobbies, interests, or how you like to spend your free time.',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _funActivitiesController,
            maxLines: 5,
            maxLength: 500,
            onChanged: (value) => provider.setFunActivities(value),
            decoration: InputDecoration(
              hintText: 'e.g., I love playing volleyball, watching movies, trying new restaurants, and exploring the city...',
              hintStyle: TextStyle(color: AppColors.textHint),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTalkAboutPage(MatchingProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What topics could you talk about forever?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Share the subjects that get you excited and engaged in conversation.',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _talkAboutController,
            maxLines: 5,
            maxLength: 500,
            onChanged: (value) => provider.setTalkAboutForever(value),
            decoration: InputDecoration(
              hintText: 'e.g., Technology, travel stories, music, philosophy, sports, entrepreneurship...',
              hintStyle: TextStyle(color: AppColors.textHint),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFreeTimePage(MatchingProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'When are you usually free?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tell us about your typical schedule so we can suggest good times for activities.',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _freeTimeController,
            maxLines: 5,
            maxLength: 500,
            onChanged: (value) => provider.setFreeTime(value),
            decoration: InputDecoration(
              hintText: 'e.g., I\'m usually free on weekday evenings after 6pm, and most of Saturday. Sunday mornings I have practice...',
              hintStyle: TextStyle(color: AppColors.textHint),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingPage(
    MatchingProvider provider,
    String ratingKey,
    String question,
    String description,
    int currentRating,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 48),
          RatingButtonRow(
            selectedRating: currentRating,
            onRatingChanged: (rating) => provider.setRating(ratingKey, rating),
            lowLabel: 'Not my thing',
            highLabel: 'Love it!',
          ),
          const SizedBox(height: 48),
          // Visual indicator of current selection
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _getRatingLabel(currentRating),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getRatingLabel(int rating) {
    switch (rating) {
      case 1:
        return 'Not interested';
      case 2:
        return 'Meh, sometimes';
      case 3:
        return 'It\'s okay';
      case 4:
        return 'I enjoy it';
      case 5:
        return 'I love it!';
      default:
        return '';
    }
  }

  Widget _buildElaborationPage(MatchingProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Anything else about your activity preferences?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Optional — expand on your ratings, mention things you love or hate doing with friends, or add activities that weren\'t listed above.',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _elaborationController,
            maxLines: 5,
            maxLength: 500,
            onChanged: (value) => provider.setActivityPreferencesElaboration(value),
            decoration: InputDecoration(
              hintText: 'e.g., I rated outdoors low but I love beach days specifically. I\'m also really into karaoke and escape rooms...',
              hintStyle: TextStyle(color: AppColors.textHint),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.divider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFriendTypePage(MatchingProvider provider) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tell us about your friend style',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This helps us find people who complement your personality.',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          _buildFriendTypeField(
            label: 'What type of friend are you?',
            hint: 'e.g., I\'m the planner of the group, always organizing hangouts...',
            controller: _friendTypeController,
            onChanged: provider.setFriendType,
          ),
          const SizedBox(height: 20),
          _buildFriendTypeField(
            label: 'What type of friend do you match well with?',
            hint: 'e.g., Spontaneous people who are down for anything...',
            controller: _friendTypeMatchWellController,
            onChanged: provider.setFriendTypeMatchWell,
          ),
          const SizedBox(height: 20),
          _buildFriendTypeField(
            label: 'What type of friend do you NOT match well with?',
            hint: 'e.g., People who cancel plans last minute or are very introverted...',
            controller: _friendTypeNoMatchController,
            onChanged: provider.setFriendTypeNoMatch,
          ),
        ],
      ),
    );
  }

  Widget _buildFriendTypeField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: 3,
          maxLength: 500,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.textHint),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.divider),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.divider),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationButtons(MatchingProvider provider) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          if (provider.canGoBack)
            Expanded(
              child: CustomButton(
                text: 'Back',
                onPressed: () {
                  provider.previousQuestion();
                  _goToPage(provider.currentQuestionIndex);
                },
                isOutlined: true,
              ),
            ),
          if (provider.canGoBack) const SizedBox(width: 16),
          Expanded(
            flex: provider.canGoBack ? 1 : 2,
            child: CustomButton(
              text: provider.isLastQuestion ? 'Submit' : 'Next',
              isLoading: provider.isSubmitting,
              onPressed: provider.canProceed
                  ? () {
                      if (provider.isLastQuestion) {
                        _handleSubmit();
                      } else {
                        provider.nextQuestion();
                        _goToPage(provider.currentQuestionIndex);
                      }
                    }
                  : null,
            ),
          ),
        ],
      ),
    );
  }

  void _showExitConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit Questionnaire?'),
        content: const Text(
          'Your progress will be lost if you exit now. Are you sure you want to leave?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              widget.onCancel();
            },
            child: const Text(
              'Exit',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}
