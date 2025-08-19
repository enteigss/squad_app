import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../../utils/colors.dart';

class EditMatchingPreferencesScreen extends StatefulWidget {
  final UserModel user;

  const EditMatchingPreferencesScreen({
    super.key,
    required this.user,
  });

  @override
  State<EditMatchingPreferencesScreen> createState() => _EditMatchingPreferencesScreenState();
}

class _EditMatchingPreferencesScreenState extends State<EditMatchingPreferencesScreen> {
  bool _isLoading = false;
  bool _isLoadingData = true;
  String? _error;
  
  // Importance ratings
  Map<String, int> _importanceRatings = {
    'deep_conversation': 2, // Default to neutral (index 2)
    'casual_hangouts': 2,
    'activities_with_friends': 2,
    'big_events_parties_nightlife': 2,
    'studies': 2,
  };
  
  // Frequency preferences
  String? _hangoutFrequency; // 'everyday', 'multiple_times_per_week', 'weekly', 'less_than_weekly'
  String? _conversationStyle; // 'yapper', 'moderate', 'listener', 'not_sure'
  String? _socialInteractionPreference; // 'no_constant_conversation', 'presence_enough', 'live_for_conversation', 'not_sure'
  
  // Gender preference for group
  String? _genderPreference;
  
  // Activity preferences - storing as maps with fun level and frequency
  Map<String, Map<String, int>> _activityPreferences = {
    'frat_party': {'fun': 2, 'frequency': 2},
    'eating_out': {'fun': 2, 'frequency': 2},
    'bar_crawl': {'fun': 2, 'frequency': 2},
    'movie_theater': {'fun': 2, 'frequency': 2},
    'fun_games': {'fun': 2, 'frequency': 2},
    'physical_activity': {'fun': 2, 'frequency': 2},
    'concerts': {'fun': 2, 'frequency': 2},
    'dancing_clubbing': {'fun': 2, 'frequency': 2},
    'outdoor_activities': {'fun': 2, 'frequency': 2},
    'watch_movie_in': {'fun': 2, 'frequency': 2},
    'board_games': {'fun': 2, 'frequency': 2},
    'hangout_vibe': {'fun': 2, 'frequency': 2},
    'play_games_casual': {'fun': 2, 'frequency': 2},
    'play_games_competitive': {'fun': 2, 'frequency': 2},
    'cooking_baking': {'fun': 2, 'frequency': 2},
  };

  final List<String> _importanceOptions = [
    'Not at all',
    'Slightly',
    'Neutral',
    'Important',
    'Very',
  ];

  final Map<String, String> _importanceLabels = {
    'deep_conversation': '💭 Deep Conversation',
    'casual_hangouts': '😊 Casual Hangouts',
    'activities_with_friends': '🎯 Activities with Friends',
    'big_events_parties_nightlife': '🎉 Big Events, Parties, and Nightlife',
    'studies': '📚 Studies',
  };


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
    {'value': 'same_gender', 'label': 'Same gender'},
    {'value': 'mixed', 'label': 'Mixed'},
    {'value': 'dont_care', 'label': 'Don\'t care'},
  ];

  final List<String> _funLevels = [
    'Not fun',
    'Slightly',
    'Kind of fun',
    'Fun',
    'Very fun',
  ];

  final List<String> _frequencyLevels = [
    'Never',
    'Rarely',
    'Sometimes',
    'Often',
    'Always',
  ];

  final Map<String, String> _activityLabels = {
    'frat_party': '🎉 Frat party',
    'eating_out': '🍽️ Eating out',
    'bar_crawl': '🍻 Bar crawl',
    'movie_theater': '🎬 Watching a movie at a theater',
    'fun_games': '🎯 Fun game/competition (mini-golf, go-karting, paintball etc.)',
    'physical_activity': '💪 Physical activity',
    'concerts': '🎵 Concerts/live music',
    'dancing_clubbing': '💃 Dancing/clubbing',
    'outdoor_activities': '🌳 Outdoor activities (hiking, beach, park)',
    'watch_movie_in': '📺 Watch a movie',
    'board_games': '🎲 Play board games',
    'hangout_vibe': '😎 Just hangout and vibe',
    'play_games_casual': '🎮 Play games (casually)',
    'play_games_competitive': '🏆 Play games (competitively)',
    'cooking_baking': '👩‍🍳 Cooking and baking together',
  };

  final Map<String, String> _activityCategories = {
    'frat_party': 'Going Out',
    'eating_out': 'Going Out',
    'bar_crawl': 'Going Out',
    'movie_theater': 'Going Out',
    'fun_games': 'Going Out',
    'physical_activity': 'Going Out',
    'concerts': 'Going Out',
    'dancing_clubbing': 'Going Out',
    'outdoor_activities': 'Going Out',
    'watch_movie_in': 'Staying In',
    'board_games': 'Staying In',
    'hangout_vibe': 'Staying In',
    'play_games_casual': 'Staying In',
    'play_games_competitive': 'Staying In',
    'cooking_baking': 'Staying In',
  };

  @override
  void initState() {
    super.initState();
    _loadExistingPreferences();
  }

  Future<void> _loadExistingPreferences() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.id)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        
        setState(() {
          // Load importance ratings
          if (data['importanceRatings'] != null) {
            final ratings = Map<String, dynamic>.from(data['importanceRatings']);
            _importanceRatings = ratings.map((key, value) => MapEntry(key, value as int));
          }
          
          // Load other preferences
          _hangoutFrequency = data['hangoutFrequency'];
          _conversationStyle = data['conversationStyle'];
          _socialInteractionPreference = data['socialInteractionPreference'];
          final genderPrefs = List<String>.from(data['genderPreferences'] ?? []);
          _genderPreference = genderPrefs.isNotEmpty ? genderPrefs.first : null;
          
          // Load activity preferences
          if (data['activityPreferences'] != null) {
            final activities = Map<String, dynamic>.from(data['activityPreferences']);
            for (final key in activities.keys) {
              if (_activityPreferences.containsKey(key)) {
                _activityPreferences[key] = Map<String, int>.from(activities[key]);
              }
            }
          }
          
          _isLoadingData = false;
        });
      } else {
        setState(() {
          _isLoadingData = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to load preferences: ${e.toString()}';
        _isLoadingData = false;
      });
    }
  }

  void _setGenderPreference(String gender) {
    setState(() {
      _genderPreference = gender;
    });
  }

  Future<void> _savePreferences() async {
    // Validation
    if (_hangoutFrequency == null) {
      _showError('Please select how often you like to hang out');
      return;
    }

    if (_conversationStyle == null) {
      _showError('Please select your conversation style');
      return;
    }

    if (_socialInteractionPreference == null) {
      _showError('Please select your social interaction preference');
      return;
    }

    if (_genderPreference == null) {
      _showError('Please select your group gender preference');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      await authProvider.updatePreferences(
        importanceRatings: _importanceRatings,
        personalityType: null,
        hangoutFrequency: _hangoutFrequency,
        conversationStyle: _conversationStyle,
        socialInteractionPreference: _socialInteractionPreference,
        genderPreferences: _genderPreference != null ? [_genderPreference!] : [],
        activityPreferences: _activityPreferences,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Matching preferences updated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop(); // Go back to profile screen
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to update preferences: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showError(String message) {
    setState(() {
      _error = message;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Edit Matching Preferences'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Matching Preferences'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
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
                          color: AppColors.divider.withValues(alpha: 0.3),
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
                      'Update your matching preferences',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Modify your preferences to help us match you with the right group',
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
                            color: AppColors.divider.withValues(alpha: 0.2),
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
                                              : AppColors.divider.withValues(alpha: 0.3),
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
                                    ? AppColors.primary.withValues(alpha: 0.1)
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.divider.withValues(alpha: 0.3),
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
                                    ? AppColors.primary.withValues(alpha: 0.1)
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.divider.withValues(alpha: 0.3),
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
                                    ? AppColors.primary.withValues(alpha: 0.1)
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.divider.withValues(alpha: 0.3),
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

                    // Gender Preference Section
                    Text(
                      'Group Gender Preference',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'What type of group would you prefer?',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Column(
                      children: _genderOptions.map((option) {
                        final isSelected = _genderPreference == option['value'];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: GestureDetector(
                            onTap: () => _setGenderPreference(option['value']!),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 16,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary.withValues(alpha: 0.1)
                                    : AppColors.surface,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.divider.withValues(alpha: 0.3),
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

                    const SizedBox(height: 32),

                    // Error message
                    if (_error != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          _error!,
                          style: TextStyle(color: AppColors.error, fontSize: 14),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Save Button - Fixed at bottom
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: CustomButton(
                text: _isLoading ? 'Saving...' : 'Save Changes',
                onPressed: _isLoading ? null : _savePreferences,
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