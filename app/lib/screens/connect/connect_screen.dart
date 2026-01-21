import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/matching_provider.dart';
import 'connect_intro_screen.dart';
import 'questionnaire_screen.dart';
import 'questionnaire_confirmation_screen.dart';
import 'matching_profile_edit_screen.dart';

enum ConnectViewState {
  intro,
  questionnaire,
  confirmation,
  edit,
}

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  ConnectViewState _currentView = ConnectViewState.intro;

  @override
  void initState() {
    super.initState();
    _determineInitialView();
  }

  void _determineInitialView() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final hasMatchingProfile = authProvider.currentUser?.matchingProfile != null &&
          authProvider.currentUser!.matchingProfile!.isActive;

      if (hasMatchingProfile) {
        setState(() {
          _currentView = ConnectViewState.edit;
        });
      }
    });
  }

  void _startQuestionnaire() {
    final matchingProvider = Provider.of<MatchingProvider>(context, listen: false);
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
    final hasMatchingProfile = authProvider.currentUser?.matchingProfile != null &&
        authProvider.currentUser!.matchingProfile!.isActive;

    setState(() {
      _currentView = hasMatchingProfile ? ConnectViewState.edit : ConnectViewState.intro;
    });
  }

  void _onConfirmationDone() {
    setState(() {
      _currentView = ConnectViewState.edit;
    });
  }

  void _onEditResponses() {
    _startQuestionnaire();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // Re-check profile state when auth changes
        final hasMatchingProfile = authProvider.currentUser?.matchingProfile != null &&
            authProvider.currentUser!.matchingProfile!.isActive;

        // If we're on intro but user has profile, switch to edit
        if (_currentView == ConnectViewState.intro && hasMatchingProfile) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            setState(() {
              _currentView = ConnectViewState.edit;
            });
          });
        }

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
            return QuestionnaireConfirmationScreen(
              onDone: _onConfirmationDone,
            );
          case ConnectViewState.edit:
            return MatchingProfileEditScreen(
              onEditResponses: _onEditResponses,
            );
        }
      },
    );
  }
}
