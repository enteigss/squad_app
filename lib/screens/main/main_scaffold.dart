import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/feedback_provider.dart';
import '../../models/meetup_feedback.dart';
import '../../widgets/meetup_feedback_dialog.dart';
import '../home/home_screen.dart';
import '../feed/feed_screen.dart';
import '../profile/profile_screen.dart';
import '../squads/squads_interest_screen.dart';

class MainScaffold extends StatefulWidget {
  final int initialIndex;
  
  const MainScaffold({
    super.key,
    this.initialIndex = 0,
  });

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  late int _selectedIndex;
  late PageController _pageController;
  bool _hasInitializedFeedback = false;
  
  // Dialog state management
  bool _isShowingFeedbackDialog = false;
  Set<String> _shownPromptIds = {};
  Timer? _pendingPromptTimer;

  final List<Widget> _screens = [
    const HomeScreen(),
    const FeedScreen(),
    const SquadsInterestScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _selectedIndex);
    
    // Initialize feedback prompts after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFeedbackPrompts();
    });
  }

  void _initializeFeedbackPrompts() {
    if (!_hasInitializedFeedback && mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final feedbackProvider = Provider.of<FeedbackProvider>(context, listen: false);
      
      if (authProvider.isAuthenticated && authProvider.currentUser != null) {
        final currentUserId = authProvider.currentUser!.id;
        debugPrint('MainScaffold: Initializing feedback for userId: $currentUserId');
        feedbackProvider.initialize(currentUserId);
        _hasInitializedFeedback = true;
        
        // Set up listener for new feedback prompts
        _setupFeedbackListener();
      }
    }
  }

  void _setupFeedbackListener() {
    // Listen for changes in pending prompts and show dialog when available
    final feedbackProvider = Provider.of<FeedbackProvider>(context, listen: false);
    
    // Add a listener that will trigger when prompts become available
    feedbackProvider.addListener(_onFeedbackPromptsChanged);
  }

  void _onFeedbackPromptsChanged() {
    // Check if widget is still mounted before accessing context
    if (!mounted) return;
    
    final feedbackProvider = Provider.of<FeedbackProvider>(context, listen: false);
    
    debugPrint('MainScaffold: _onFeedbackPromptsChanged called, hasPendingPrompts: ${feedbackProvider.hasPendingPrompts}');
    
    // If there's a pending prompt and we're in the foreground, show it
    if (feedbackProvider.hasPendingPrompts && 
        feedbackProvider.nextPrompt != null &&
        !_isShowingFeedbackDialog) {
      
      final nextPrompt = feedbackProvider.nextPrompt!;
      
      // Check if we've already shown this prompt in this session
      if (_shownPromptIds.contains(nextPrompt.id)) {
        debugPrint('MainScaffold: Prompt ${nextPrompt.id} already shown in this session, skipping');
        return;
      }
      
      debugPrint('MainScaffold: Showing feedback prompt after delay');
      
      // Cancel any existing pending timer
      _pendingPromptTimer?.cancel();
      
      // Use a short delay to ensure the UI is stable
      _pendingPromptTimer = Timer(const Duration(milliseconds: 500), () {
        if (mounted && !_isShowingFeedbackDialog) {
          _showFeedbackPrompt(nextPrompt);
        }
      });
    }
  }

  void _showFeedbackPrompt(PendingFeedbackPrompt prompt) {
    // Set dialog state flags
    _isShowingFeedbackDialog = true;
    _shownPromptIds.add(prompt.id);
    
    debugPrint('MainScaffold: Showing dialog for prompt ${prompt.id}');
    
    MeetupFeedbackDialog.show(
      context,
      prompt: prompt,
      onFeedbackSubmitted: () {
        // Reset dialog state when feedback is submitted
        _isShowingFeedbackDialog = false;
        debugPrint('MainScaffold: Dialog closed after feedback submission');
        
        // Check if there are more prompts to show
        _checkForNextPrompt();
      },
    ).then((_) {
      // Reset dialog state when dialog is dismissed (including skip/cancel)
      _isShowingFeedbackDialog = false;
      debugPrint('MainScaffold: Dialog closed');
      
      // Check if there are more prompts to show
      _checkForNextPrompt();
    });
  }
  
  void _checkForNextPrompt() {
    // Small delay before checking for next prompt to avoid rapid-fire dialogs
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _onFeedbackPromptsChanged();
      }
    });
  }

  @override
  void dispose() {
    // Cancel any pending timer
    _pendingPromptTimer?.cancel();
    
    // Remove feedback listener
    if (_hasInitializedFeedback) {
      final feedbackProvider = Provider.of<FeedbackProvider>(context, listen: false);
      feedbackProvider.removeListener(_onFeedbackPromptsChanged);
    }
    
    // Clear tracking sets
    _shownPromptIds.clear();
    
    _pageController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.feed),
            label: 'Hangouts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.groups),
            label: 'Squads',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}