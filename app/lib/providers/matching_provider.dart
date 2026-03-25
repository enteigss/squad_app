import 'package:flutter/foundation.dart';
import '../models/matching_profile.dart';

class MatchingProvider extends ChangeNotifier {
  // All available activities with display labels
  static const Map<String, String> activityLabels = {
    'deepConversations': 'Deep conversations',
    'outdoors': 'Outdoor activities',
    'chilling': 'Just chilling',
    'competitiveGames': 'Competitive games',
    'meals': 'Grabbing a meal',
    'nightsOut': 'Nights out',
  };

  // Current question index (0-6)
  int _currentQuestionIndex = 0;

  // Loading states
  bool _isLoading = false;
  bool _isSubmitting = false;

  // Form data
  String? _genderPreference;
  String _funActivities = '';
  String _talkAboutForever = '';
  String _freeTime = '';
  final Set<String> _excludedActivities = {};
  List<String> _rankedActivities = [];
  String _friendType = '';
  String _friendTypeMatchWell = '';
  String _friendTypeNoMatch = '';

  // Getters
  int get currentQuestionIndex => _currentQuestionIndex;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  bool get canGoBack => _currentQuestionIndex > 0;
  bool get isLastQuestion => _currentQuestionIndex == 6;
  int get totalQuestions => 7;

  String? get genderPreference => _genderPreference;
  String get funActivities => _funActivities;
  String get talkAboutForever => _talkAboutForever;
  String get freeTime => _freeTime;
  Set<String> get excludedActivities => _excludedActivities;
  List<String> get rankedActivities => _rankedActivities;
  String get friendType => _friendType;
  String get friendTypeMatchWell => _friendTypeMatchWell;
  String get friendTypeNoMatch => _friendTypeNoMatch;

  /// Activities not excluded (available for ranking)
  List<String> get includedActivities {
    return activityLabels.keys
        .where((key) => !_excludedActivities.contains(key))
        .toList();
  }

  // Check if current question has a valid answer
  bool get canProceed {
    switch (_currentQuestionIndex) {
      case 0:
        return _genderPreference != null && _genderPreference!.isNotEmpty;
      case 1:
        return _funActivities.trim().isNotEmpty;
      case 2:
        return _talkAboutForever.trim().isNotEmpty;
      case 3:
        return _freeTime.trim().isNotEmpty;
      case 4:
        // Exclude page: must keep at least 2 activities
        return includedActivities.length >= 2;
      case 5:
        // Rank page: always valid (pre-populated)
        return true;
      case 6:
        // Friend type page: always valid
        return true;
      default:
        return true;
    }
  }

  // Navigation methods
  void nextQuestion() {
    if (_currentQuestionIndex < 6) {
      // When moving from exclude page to rank page, initialize ranked list
      if (_currentQuestionIndex == 4) {
        _initRankedActivities();
      }
      _currentQuestionIndex++;
      notifyListeners();
    }
  }

  void previousQuestion() {
    if (_currentQuestionIndex > 0) {
      _currentQuestionIndex--;
      notifyListeners();
    }
  }

  void goToQuestion(int index) {
    if (index >= 0 && index <= 6) {
      _currentQuestionIndex = index;
      notifyListeners();
    }
  }

  void resetQuestionnaire() {
    _currentQuestionIndex = 0;
    _genderPreference = null;
    _funActivities = '';
    _talkAboutForever = '';
    _freeTime = '';
    _excludedActivities.clear();
    _rankedActivities = [];
    _friendType = '';
    _friendTypeMatchWell = '';
    _friendTypeNoMatch = '';
    _isSubmitting = false;
    notifyListeners();
  }

  // Field setters
  void setGenderPreference(String? value) {
    _genderPreference = value;
    notifyListeners();
  }

  void setFunActivities(String value) {
    _funActivities = value;
    notifyListeners();
  }

  void setTalkAboutForever(String value) {
    _talkAboutForever = value;
    notifyListeners();
  }

  void setFreeTime(String value) {
    _freeTime = value;
    notifyListeners();
  }

  void toggleActivityExclusion(String activityKey) {
    if (_excludedActivities.contains(activityKey)) {
      _excludedActivities.remove(activityKey);
    } else {
      _excludedActivities.add(activityKey);
    }
    // Remove from ranked list if excluded
    _rankedActivities.remove(activityKey);
    notifyListeners();
  }

  void setRankedActivities(List<String> ranked) {
    _rankedActivities = ranked;
    notifyListeners();
  }

  void setFriendType(String value) {
    _friendType = value;
    notifyListeners();
  }

  void setFriendTypeMatchWell(String value) {
    _friendTypeMatchWell = value;
    notifyListeners();
  }

  void setFriendTypeNoMatch(String value) {
    _friendTypeNoMatch = value;
    notifyListeners();
  }

  /// Initialize ranked activities from included activities (preserving any existing order)
  void _initRankedActivities() {
    final included = includedActivities;
    // Keep existing ranked items that are still included, then append new ones
    final existing = _rankedActivities.where((a) => included.contains(a)).toList();
    final newItems = included.where((a) => !existing.contains(a)).toList();
    _rankedActivities = [...existing, ...newItems];
  }

  // Load existing profile for editing
  void loadExistingProfile(MatchingProfile profile) {
    _genderPreference = profile.genderPreference;
    _funActivities = profile.funActivities ?? '';
    _talkAboutForever = profile.talkAboutForever ?? '';
    _freeTime = profile.freeTime ?? '';
    _excludedActivities.clear();
    _excludedActivities.addAll(profile.excludedActivities);
    _rankedActivities = List<String>.from(profile.rankedActivities);
    _friendType = profile.friendType ?? '';
    _friendTypeMatchWell = profile.friendTypeMatchWell ?? '';
    _friendTypeNoMatch = profile.friendTypeNoMatch ?? '';
    _currentQuestionIndex = 0;
    notifyListeners();
  }

  // Build MatchingProfile from current form data
  MatchingProfile buildProfile() {
    // Ensure ranked activities are up to date
    _initRankedActivities();
    return MatchingProfile(
      isActive: true,
      genderPreference: _genderPreference,
      funActivities: _funActivities.trim(),
      talkAboutForever: _talkAboutForever.trim(),
      freeTime: _freeTime.trim(),
      excludedActivities: _excludedActivities.toList(),
      rankedActivities: _rankedActivities,
      friendType: _friendType.trim().isEmpty ? null : _friendType.trim(),
      friendTypeMatchWell: _friendTypeMatchWell.trim().isEmpty ? null : _friendTypeMatchWell.trim(),
      friendTypeNoMatch: _friendTypeNoMatch.trim().isEmpty ? null : _friendTypeNoMatch.trim(),
      updatedAt: DateTime.now(),
    );
  }

  // Set submitting state
  void setSubmitting(bool value) {
    _isSubmitting = value;
    notifyListeners();
  }
}
