import 'package:flutter/foundation.dart';
import '../models/matching_profile.dart';

class MatchingProvider extends ChangeNotifier {
  // Current question index (0-11)
  int _currentQuestionIndex = 0;

  // Loading states
  bool _isLoading = false;
  bool _isSubmitting = false;

  // Form data
  String? _genderPreference;
  String _funActivities = '';
  String _talkAboutForever = '';
  String _freeTime = '';
  int _deepConversationsRating = 3;
  int _outdoorsRating = 3;
  int _chillingRating = 3;
  int _competitiveGamesRating = 3;
  int _mealsRating = 3;
  int _nightsOutRating = 3;
  String _activityPreferencesElaboration = '';
  String _friendType = '';
  String _friendTypeMatchWell = '';
  String _friendTypeNoMatch = '';

  // Getters
  int get currentQuestionIndex => _currentQuestionIndex;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  bool get canGoBack => _currentQuestionIndex > 0;
  bool get isLastQuestion => _currentQuestionIndex == 11;
  int get totalQuestions => 12;

  String? get genderPreference => _genderPreference;
  String get funActivities => _funActivities;
  String get talkAboutForever => _talkAboutForever;
  String get freeTime => _freeTime;
  int get deepConversationsRating => _deepConversationsRating;
  int get outdoorsRating => _outdoorsRating;
  int get chillingRating => _chillingRating;
  int get competitiveGamesRating => _competitiveGamesRating;
  int get mealsRating => _mealsRating;
  int get nightsOutRating => _nightsOutRating;
  String get activityPreferencesElaboration => _activityPreferencesElaboration;
  String get friendType => _friendType;
  String get friendTypeMatchWell => _friendTypeMatchWell;
  String get friendTypeNoMatch => _friendTypeNoMatch;

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
      default:
        // Rating questions (4-9), elaboration (10), friend type (11) always valid
        return true;
    }
  }

  // Navigation methods
  void nextQuestion() {
    if (_currentQuestionIndex < 11) {
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
    if (index >= 0 && index <= 11) {
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
    _deepConversationsRating = 3;
    _outdoorsRating = 3;
    _chillingRating = 3;
    _competitiveGamesRating = 3;
    _mealsRating = 3;
    _nightsOutRating = 3;
    _activityPreferencesElaboration = '';
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

  void setRating(String ratingType, int value) {
    if (value < 1 || value > 5) return;

    switch (ratingType) {
      case 'deepConversations':
        _deepConversationsRating = value;
        break;
      case 'outdoors':
        _outdoorsRating = value;
        break;
      case 'chilling':
        _chillingRating = value;
        break;
      case 'competitiveGames':
        _competitiveGamesRating = value;
        break;
      case 'meals':
        _mealsRating = value;
        break;
      case 'nightsOut':
        _nightsOutRating = value;
        break;
    }
    notifyListeners();
  }

  void setActivityPreferencesElaboration(String value) {
    _activityPreferencesElaboration = value;
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

  // Load existing profile for editing
  void loadExistingProfile(MatchingProfile profile) {
    _genderPreference = profile.genderPreference;
    _funActivities = profile.funActivities ?? '';
    _talkAboutForever = profile.talkAboutForever ?? '';
    _freeTime = profile.freeTime ?? '';
    _deepConversationsRating = profile.activityRatings.deepConversations;
    _outdoorsRating = profile.activityRatings.outdoors;
    _chillingRating = profile.activityRatings.chilling;
    _competitiveGamesRating = profile.activityRatings.competitiveGames;
    _mealsRating = profile.activityRatings.meals;
    _nightsOutRating = profile.activityRatings.nightsOut;
    _activityPreferencesElaboration = profile.activityPreferencesElaboration ?? '';
    _friendType = profile.friendType ?? '';
    _friendTypeMatchWell = profile.friendTypeMatchWell ?? '';
    _friendTypeNoMatch = profile.friendTypeNoMatch ?? '';
    _currentQuestionIndex = 0;
    notifyListeners();
  }

  // Build MatchingProfile from current form data
  MatchingProfile buildProfile() {
    return MatchingProfile(
      isActive: true,
      genderPreference: _genderPreference,
      funActivities: _funActivities.trim(),
      talkAboutForever: _talkAboutForever.trim(),
      freeTime: _freeTime.trim(),
      activityRatings: ActivityRatings(
        deepConversations: _deepConversationsRating,
        outdoors: _outdoorsRating,
        chilling: _chillingRating,
        competitiveGames: _competitiveGamesRating,
        meals: _mealsRating,
        nightsOut: _nightsOutRating,
      ),
      activityPreferencesElaboration: _activityPreferencesElaboration.trim().isEmpty ? null : _activityPreferencesElaboration.trim(),
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
