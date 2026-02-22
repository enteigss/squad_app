import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/matched_group_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/matching_provider.dart';
import '../../services/matched_group_service.dart';
import 'connect_intro_screen.dart';
import 'questionnaire_screen.dart';
import 'questionnaire_confirmation_screen.dart';
import 'matching_profile_edit_screen.dart';
import 'matched_groups_list_screen.dart';
import 'matched_group_info_screen.dart';

enum ConnectViewState {
  intro,
  questionnaire,
  confirmation,
  edit,
  matchedList,
  matchedGroupInfo,
}

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  ConnectViewState _currentView = ConnectViewState.intro;
  MatchedGroupModel? _selectedGroup;
  final MatchedGroupService _matchedGroupService = MatchedGroupService();
  bool _isCheckingMatches = true;
  bool _hasMatchedGroups = false;

  @override
  void initState() {
    super.initState();
    _determineInitialView();
  }

  Future<void> _determineInitialView() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final userId = authProvider.currentUser?.id;

    if (userId == null) {
      setState(() {
        _isCheckingMatches = false;
        _currentView = ConnectViewState.intro;
      });
      return;
    }

    // First check if user has any matched groups
    try {
      final groupsStream = _matchedGroupService.getMatchedGroupsForUser(userId);
      final groups = await groupsStream.first;

      if (groups.isNotEmpty) {
        setState(() {
          _isCheckingMatches = false;
          _hasMatchedGroups = true;
          _currentView = ConnectViewState.matchedList;
        });
        return;
      }
    } catch (e) {
      debugPrint('Error checking matched groups: $e');
    }

    // Fall back to existing logic
    final hasMatchingProfile =
        authProvider.currentUser?.matchingProfile != null &&
        authProvider.currentUser!.matchingProfile!.isActive;

    setState(() {
      _isCheckingMatches = false;
      _hasMatchedGroups = false;
      _currentView = hasMatchingProfile
          ? ConnectViewState.edit
          : ConnectViewState.intro;
    });
  }

  void _startQuestionnaire() {
    final matchingProvider = Provider.of<MatchingProvider>(
      context,
      listen: false,
    );
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // If editing existing profile, load the values
    final existingProfile = authProvider.currentUser?.matchingProfile;
    if (existingProfile != null) {
      matchingProvider.loadExistingProfile(existingProfile);
    } else {
      matchingProvider.resetQuestionnaire();
    }

    setState(() {
      _currentView = ConnectViewState.questionnaire;
    });
  }

  void _onQuestionnaireComplete() {
    setState(() {
      _currentView = ConnectViewState.confirmation;
    });
  }

  void _onQuestionnaireCancel() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final hasMatchingProfile =
        authProvider.currentUser?.matchingProfile != null &&
        authProvider.currentUser!.matchingProfile!.isActive;

    setState(() {
      if (_hasMatchedGroups) {
        _currentView = ConnectViewState.matchedList;
      } else if (hasMatchingProfile) {
        _currentView = ConnectViewState.edit;
      } else {
        _currentView = ConnectViewState.intro;
      }
    });
  }

  void _onConfirmationDone() {
    setState(() {
      _currentView = _hasMatchedGroups
          ? ConnectViewState.matchedList
          : ConnectViewState.edit;
    });
  }

  void _onEditResponses() {
    _startQuestionnaire();
  }

  void _onGroupTap(MatchedGroupModel group) {
    setState(() {
      _selectedGroup = group;
      _currentView = ConnectViewState.matchedGroupInfo;
    });
  }

  void _onBackFromGroupInfo() {
    setState(() {
      _selectedGroup = null;
      _currentView = ConnectViewState.matchedList;
    });
  }

  void _onEditProfileFromList() {
    setState(() {
      _currentView = ConnectViewState.edit;
    });
  }

  void _onBackFromEdit() {
    setState(() {
      if (_hasMatchedGroups) {
        _currentView = ConnectViewState.matchedList;
      } else {
        // Stay on edit screen - nowhere to go back to
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Show loading while checking for matches
    if (_isCheckingMatches) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        switch (_currentView) {
          case ConnectViewState.intro:
            return ConnectIntroScreen(
              onStartQuestionnaire: _startQuestionnaire,
            );
          case ConnectViewState.questionnaire:
            return QuestionnaireScreen(
              onComplete: _onQuestionnaireComplete,
              onCancel: _onQuestionnaireCancel,
            );
          case ConnectViewState.confirmation:
            return QuestionnaireConfirmationScreen(onDone: _onConfirmationDone);
          case ConnectViewState.edit:
            return MatchingProfileEditScreen(onEditResponses: _onEditResponses);
          case ConnectViewState.matchedList:
            return MatchedGroupsListScreen(
              onGroupTap: _onGroupTap,
              onEditProfile: _onEditProfileFromList,
            );
          case ConnectViewState.matchedGroupInfo:
            if (_selectedGroup == null) {
              // Safety fallback
              WidgetsBinding.instance.addPostFrameCallback((_) {
                setState(() => _currentView = ConnectViewState.matchedList);
              });
              return const SizedBox.shrink();
            }
            return MatchedGroupInfoScreen(
              group: _selectedGroup!,
              onBack: _onBackFromGroupInfo,
            );
        }
      },
    );
  }
}
