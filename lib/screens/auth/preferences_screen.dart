import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../../utils/colors.dart';

class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  bool _isLoading = false;
  
  // Importance ratings
  Map<String, int> _importanceRatings = {
    'deep_conversation': 2, // Default to neutral (index 2)
    'casual_hangouts': 2,
    'activities_with_friends': 2,
    'big_events_parties_nightlife': 2,
    'studies': 2,
  };
  
  // Personality and frequency preferences
  String? _personalityType; // 'extrovert', 'introvert', 'not_sure'
  String? _hangoutFrequency; // 'everyday', 'multiple_times_per_week', 'weekly', 'less_than_weekly'
  String? _conversationStyle; // 'yapper', 'moderate', 'listener', 'not_sure'
  String? _socialInteractionPreference; // 'no_constant_conversation', 'presence_enough', 'live_for_conversation', 'not_sure'
  
  // Gender preferences for group
  List<String> _genderPreferences = [];

  final List<String> _importanceOptions = [
    'Not important at all',
    'Not very important',
    'Neutral',
    'Important',
    'Very important',
  ];

  final Map<String, String> _importanceLabels = {
    'deep_conversation': 'Deep Conversation',
    'casual_hangouts': 'Casual Hangouts',
    'activities_with_friends': 'Activities with Friends',
    'big_events_parties_nightlife': 'Big Events, Parties, and Nightlife',
    'studies': 'Studies',
  };

  final List<Map<String, String>> _personalityOptions = [
    {'value': 'extrovert', 'label': 'Extrovert'},
    {'value': 'introvert', 'label': 'Introvert'},
    {'value': 'not_sure', 'label': 'Not Sure'},
  ];

  final List<Map<String, String>> _hangoutFrequencyOptions = [
    {'value': 'everyday', 'label': 'Everyday'},
    {'value': 'multiple_times_per_week', 'label': 'Multiple times per week'},
    {'value': 'weekly', 'label': 'Weekly'},
    {'value': 'less_than_weekly', 'label': 'Less than weekly'},
  ];

  final List<Map<String, String>> _conversationStyleOptions = [
    {'value': 'yapper', 'label': 'I\'m a yapper'},
    {'value': 'moderate', 'label': 'A moderate amount'},
    {'value': 'listener', 'label': 'I\'m content listening'},
    {'value': 'not_sure', 'label': 'Not sure'},
  ];

  final List<Map<String, String>> _socialInteractionOptions = [
    {'value': 'presence_enough', 'label': 'I don\'t need constant conversation, my friends\' presence is enough'},
    {'value': 'live_for_conversation', 'label': 'I live for conversation'},
    {'value': 'not_sure', 'label': 'Not sure'},
  ];

  final List<Map<String, String>> _genderOptions = [
    {'value': 'women', 'label': 'Women'},
    {'value': 'men', 'label': 'Men'},
    {'value': 'non_binary', 'label': 'Non-binary'},
  ];

  void _toggleGenderPreference(String gender) {
    setState(() {
      if (_genderPreferences.contains(gender)) {
        _genderPreferences.remove(gender);
      } else {
        _genderPreferences.add(gender);
      }
    });
  }

  Future<void> _completePreferences() async {
    // Validation
    if (_personalityType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your personality type'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_hangoutFrequency == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select how often you like to hang out'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_conversationStyle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your conversation style'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_socialInteractionPreference == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your social interaction preference'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_genderPreferences.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one gender preference for your group'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      await authProvider.updatePreferences(
        importanceRatings: _importanceRatings,
        personalityType: _personalityType,
        hangoutFrequency: _hangoutFrequency,
        conversationStyle: _conversationStyle,
        socialInteractionPreference: _socialInteractionPreference,
        genderPreferences: _genderPreferences,
      );

      if (mounted) {
        // Navigate to availability screen using GoRouter
        context.go('/availability');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save preferences: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Your Preferences'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Privacy Notice
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.divider.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lock,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Your preferences are private and won\'t be visible to other users',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      'Tell us about your preferences',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Help us match you with the right group by sharing your preferences',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Importance Ratings Section
                    Text(
                      'What\'s Important to You?',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Rate how important these activities are to you',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Importance Rating Cards
                    ..._importanceRatings.keys.map((key) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.divider.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _importanceLabels[key]!,
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: List.generate(5, (index) {
                                final isSelected = _importanceRatings[key] == index;
                                return Expanded(
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _importanceRatings[key] = index;
                                      });
                                    },
                                    child: Container(
                                      margin: EdgeInsets.only(
                                        right: index < 4 ? 8 : 0,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                        horizontal: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.primary
                                            : AppColors.background,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isSelected
                                              ? AppColors.primary
                                              : AppColors.divider.withOpacity(0.3),
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          _importanceOptions[index],
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: isSelected
                                                    ? Colors.white
                                                    : AppColors.textSecondary,
                                                fontWeight: isSelected
                                                    ? FontWeight.w500
                                                    : FontWeight.normal,
                                              ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ],
                        ),
                      );
                    }).toList(),

                    const SizedBox(height: 24),

                    // Personality Type Section
                    Text(
                      'Personality Type',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'How would you describe yourself?',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    Row(
                      children: _personalityOptions.map((option) {
                        final isSelected = _personalityType == option['value'];
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _personalityType = option['value'];
                              });
                            },
                            child: Container(
                              margin: EdgeInsets.only(
                                right: option != _personalityOptions.last ? 8 : 0,
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.divider.withOpacity(0.3),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  option['label']!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.textPrimary,
                                        fontWeight: isSelected
                                            ? FontWeight.w500
                                            : FontWeight.normal,
                                      ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),

                    // Hangout Frequency Section
                    Text(
                      'Hangout Frequency',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'How often do you like to hang out?',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Column(
                      children: _hangoutFrequencyOptions.map((option) {
                        final isSelected = _hangoutFrequency == option['value'];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _hangoutFrequency = option['value'];
                              });
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary.withOpacity(0.1)
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.divider.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected
                                          ? AppColors.primary
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.primary
                                            : AppColors.divider,
                                        width: 2,
                                      ),
                                    ),
                                    child: isSelected
                                        ? const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 14,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    option['label']!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: isSelected
                                              ? AppColors.primary
                                              : AppColors.textPrimary,
                                          fontWeight: isSelected
                                              ? FontWeight.w500
                                              : FontWeight.normal,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),

                    // Conversation Style Section
                    Text(
                      'Conversation Style',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Which one do you identify with most?',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Column(
                      children: _conversationStyleOptions.map((option) {
                        final isSelected = _conversationStyle == option['value'];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _conversationStyle = option['value'];
                              });
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary.withOpacity(0.1)
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.divider.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected
                                          ? AppColors.primary
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.primary
                                            : AppColors.divider,
                                        width: 2,
                                      ),
                                    ),
                                    child: isSelected
                                        ? const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 14,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    option['label']!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: isSelected
                                              ? AppColors.primary
                                              : AppColors.textPrimary,
                                          fontWeight: isSelected
                                              ? FontWeight.w500
                                              : FontWeight.normal,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),

                    // Social Interaction Preference Section
                    Text(
                      'Social Interaction',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Which do you identify most with?',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Column(
                      children: _socialInteractionOptions.map((option) {
                        final isSelected = _socialInteractionPreference == option['value'];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _socialInteractionPreference = option['value'];
                              });
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary.withOpacity(0.1)
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.divider.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected
                                          ? AppColors.primary
                                          : Colors.transparent,
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.primary
                                            : AppColors.divider,
                                        width: 2,
                                      ),
                                    ),
                                    child: isSelected
                                        ? const Icon(
                                            Icons.check,
                                            color: Colors.white,
                                            size: 14,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      option['label']!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                            color: isSelected
                                                ? AppColors.primary
                                                : AppColors.textPrimary,
                                            fontWeight: isSelected
                                                ? FontWeight.w500
                                                : FontWeight.normal,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 24),

                    // Gender Preferences Section
                    Text(
                      'Group Gender Preferences',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Who would you like to have in your group? (Select all that apply)',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _genderOptions.map((option) {
                        final isSelected = _genderPreferences.contains(option['value']);
                        return GestureDetector(
                          onTap: () => _toggleGenderPreference(option['value']!),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 20,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.surface,
                              borderRadius: BorderRadius.circular(25),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : AppColors.divider.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isSelected)
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                if (isSelected) const SizedBox(width: 6),
                                Text(
                                  option['label']!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: isSelected
                                            ? Colors.white
                                            : AppColors.textPrimary,
                                        fontWeight: isSelected
                                            ? FontWeight.w500
                                            : FontWeight.normal,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Complete Preferences Button - Fixed at bottom
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: CustomButton(
                text: 'Continue',
                onPressed: _completePreferences,
                isLoading: _isLoading,
                width: double.infinity,
                height: 52,
              ),
            ),
          ],
        ),
      ),
    );
  }
}