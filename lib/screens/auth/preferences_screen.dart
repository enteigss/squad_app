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
  
  // Frequency preferences
  String? _hangoutFrequency; // 'everyday', 'multiple_times_per_week', 'weekly', 'less_than_weekly'
  String? _conversationStyle; // 'yapper', 'moderate', 'listener', 'not_sure'
  String? _socialInteractionPreference; // 'no_constant_conversation', 'presence_enough', 'live_for_conversation', 'not_sure'
  
  // User's own gender identity
  String? _userGender;
  
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

  final List<Map<String, String>> _userGenderOptions = [
    {'value': 'woman', 'label': 'Woman'},
    {'value': 'man', 'label': 'Man'},
    {'value': 'non_binary', 'label': 'Non-binary'},
    {'value': 'prefer_not_to_say', 'label': 'Prefer not to say'},
  ];

  // Dynamic gender preference options based on user's gender
  List<Map<String, String>> _getGenderPreferenceOptions() {
    if (_userGender == null) {
      return []; // No options if user hasn't selected their gender
    }
    
    final baseOptions = [
      {'value': 'anyone', 'label': 'Anyone'},
    ];
    
    // Add gender-specific option based on user's selection
    switch (_userGender) {
      case 'woman':
        baseOptions.insert(0, {'value': 'women_only', 'label': 'Women only'});
        break;
      case 'man':
        baseOptions.insert(0, {'value': 'men_only', 'label': 'Men only'});
        break;
      case 'non_binary':
        baseOptions.insert(0, {'value': 'non_binary_only', 'label': 'Non-binary only'});
        break;
      // 'prefer_not_to_say' users only see 'Anyone'
    }
    
    return baseOptions;
  }

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

  void _setUserGender(String gender) {
    setState(() {
      _userGender = gender;
      // Reset gender preference when user changes their gender
      _genderPreference = null;
    });
  }

  void _setGenderPreference(String gender) {
    setState(() {
      _genderPreference = gender;
    });
  }

  List<Widget> _buildActivityCards() {
    final groupedActivities = <String, List<String>>{};
    
    // Group activities by category
    for (final activity in _activityPreferences.keys) {
      final category = _activityCategories[activity]!;
      if (!groupedActivities.containsKey(category)) {
        groupedActivities[category] = [];
      }
      groupedActivities[category]!.add(activity);
    }

    final cards = <Widget>[];
    
    for (final category in groupedActivities.keys) {
      // Category header
      cards.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            category,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
      );

      // Activity cards for this category
      for (final activity in groupedActivities[category]!) {
        cards.add(_buildActivityCard(activity));
        cards.add(const SizedBox(height: 16));
      }

      // Add extra space between categories
      if (category != groupedActivities.keys.last) {
        cards.add(const SizedBox(height: 8));
      }
    }

    return cards;
  }

  Widget _buildActivityCard(String activityKey) {
    final funLevel = _activityPreferences[activityKey]!['fun']!;
    final frequencyLevel = _activityPreferences[activityKey]!['frequency']!;
    
    return Container(
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
            _activityLabels[activityKey]!,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          
          // Fun level rating
          Text(
            'How fun does this sound?',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (index) {
              final isSelected = funLevel == index;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _activityPreferences[activityKey]!['fun'] = index;
                    });
                  },
                  child: Container(
                    margin: EdgeInsets.only(right: index < 4 ? 4 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.background,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected 
                            ? AppColors.primary 
                            : AppColors.divider.withOpacity(0.3),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _funLevels[index],
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                          fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                          fontSize: 10,
                          height: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          
          const SizedBox(height: 16),
          
          // Frequency rating
          Text(
            'How often would you like to do this?',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (index) {
              final isSelected = frequencyLevel == index;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _activityPreferences[activityKey]!['frequency'] = index;
                    });
                  },
                  child: Container(
                    margin: EdgeInsets.only(right: index < 4 ? 4 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.background,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isSelected 
                            ? AppColors.primary 
                            : AppColors.divider.withOpacity(0.3),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _frequencyLevels[index],
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isSelected ? Colors.white : AppColors.textSecondary,
                          fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                          fontSize: 10,
                          height: 1.2,
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
  }

  Future<void> _completePreferences() async {
    // Validation
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

    // Only require gender preference if user has selected their gender
    if (_userGender != null && _userGender != 'prefer_not_to_say' && _genderPreference == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your group gender preference'),
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
        personalityType: null,
        hangoutFrequency: _hangoutFrequency,
        conversationStyle: _conversationStyle,
        socialInteractionPreference: _socialInteractionPreference,
        genderPreferences: _genderPreference != null ? [_genderPreference!] : [],
        activityPreferences: _activityPreferences,
        userGender: _userGender,
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

                    // User Gender Identity Section
                    Text(
                      'Gender Identity (Optional)',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This information helps us match you with compatible groups and is never shown to other users',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),

                    Column(
                      children: _userGenderOptions.map((option) {
                        final isSelected = _userGender == option['value'];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: GestureDetector(
                            onTap: () => _setUserGender(option['value']!),
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
                                        right: index < 4 ? 6 : 0,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                        horizontal: 2,
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
                                                fontSize: 10,
                                                height: 1.2,
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

                    // Gender Preference Section - Only show if user has selected a gender (except prefer not to say)
                    if (_userGender != null && _userGender != 'prefer_not_to_say') ...[
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
                        children: _getGenderPreferenceOptions().map((option) {
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
                    ],

                    const SizedBox(height: 32),

                    // Activity Preferences Section
                    Text(
                      'Activity Preferences',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'For each activity, rate how fun it sounds and how often you\'d like to do it',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Activity Cards
                    ..._buildActivityCards(),

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