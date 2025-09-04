import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/tab_navigation_provider.dart';
import '../../models/meetup_feedback.dart';
import '../../services/feedback_service.dart';
import '../../widgets/meetup_outcome_dialog.dart';
import '../home/home_screen.dart';
import '../feed/feed_screen.dart';
import '../feed/create_post_screen.dart';
import '../profile/profile_screen.dart';

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
  late PageController _pageController;
  final FeedbackService _feedbackService = FeedbackService();
  
  bool _hasInitializedFeedback = false;
  bool _isShowingFeedbackDialog = false;
  Set<String> _shownPromptIds = {};
  Timer? _pendingPromptTimer;
  StreamSubscription<List<PendingFeedbackPrompt>>? _promptsSubscription;

  final List<Widget> _screens = [
    const FeedScreen(),
    const CreatePostScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
    
    // Set initial tab in provider after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tabProvider = Provider.of<TabNavigationProvider>(context, listen: false);
      tabProvider.setSelectedIndex(widget.initialIndex);
      tabProvider.addListener(_onTabChangeByProvider);
    });
    
    // Initialize feedback prompts after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFeedbackPrompts();
    });
  }

  void _onTabChangeByProvider() {
    final tabProvider = Provider.of<TabNavigationProvider>(context, listen: false);
    if (_pageController.page?.round() != tabProvider.selectedIndex) {
      _pageController.animateToPage(
        tabProvider.selectedIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _initializeFeedbackPrompts() {
    if (!_hasInitializedFeedback && mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      if (authProvider.isAuthenticated && authProvider.currentUser != null) {
        final currentUserId = authProvider.currentUser!.id;
        debugPrint('MainScaffold: Initializing feedback for userId: $currentUserId');
        _hasInitializedFeedback = true;
        
        // Set up direct listener for feedback prompts
        _setupFeedbackListener(currentUserId);
      }
    }
  }

  void _setupFeedbackListener(String userId) {
    // Listen directly to feedback service for pending prompts
    _promptsSubscription = _feedbackService.getPendingFeedbackPrompts(userId).listen(
      (prompts) {
        debugPrint('MainScaffold: Received ${prompts.length} pending prompts');
        if (prompts.isNotEmpty && !_isShowingFeedbackDialog) {
          final nextPrompt = prompts.first;
          
          // Check if we've already shown this prompt in this session
          if (!_shownPromptIds.contains(nextPrompt.id)) {
            _showFeedbackPrompt(nextPrompt);
          }
        }
      },
      onError: (error) {
        debugPrint('MainScaffold: Error loading prompts: $error');
      },
    );
  }


  void _showFeedbackPrompt(PendingFeedbackPrompt prompt) {
    _isShowingFeedbackDialog = true;
    _shownPromptIds.add(prompt.id);
    
    debugPrint('MainScaffold: Showing feedback dialog for prompt ${prompt.id}');
    
    MeetupOutcomeDialog.show(
      context,
      hangoutTitle: prompt.hangoutTitle,
      contextText: 'How did it go?',
      actionButtonText: 'Submit',
      headerIcon: Icons.feedback_outlined,
      headerColor: AppColors.primary,
      onCancel: () {
        _isShowingFeedbackDialog = false;
        debugPrint('MainScaffold: Dialog skipped');
      },
      onConfirmDelete: (didMeetup) async {
        try {
          await _feedbackService.submitFeedback(
            hangoutId: prompt.hangoutId,
            userId: prompt.userId,
            hangoutTitle: prompt.hangoutTitle,
            didMeetup: didMeetup,
            additionalFeedback: null,
          );
          
          _isShowingFeedbackDialog = false;
          debugPrint('MainScaffold: Feedback submitted');
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  didMeetup 
                      ? 'Thanks for the feedback! Glad your hangout was successful! 🎉'
                      : 'Thanks for the feedback! We\'ll work on improving the experience.',
                ),
                backgroundColor: didMeetup ? AppColors.success : AppColors.primary,
              ),
            );
          }
        } catch (e) {
          _isShowingFeedbackDialog = false;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to submit feedback. Please try again.'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        }
      },
    );
  }
  

  @override
  void dispose() {
    _pendingPromptTimer?.cancel();
    _promptsSubscription?.cancel();
    _shownPromptIds.clear();
    _pageController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    final tabProvider = Provider.of<TabNavigationProvider>(context, listen: false);
    tabProvider.setSelectedIndex(index);
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
          final tabProvider = Provider.of<TabNavigationProvider>(context, listen: false);
          tabProvider.setSelectedIndex(index);
        },
        children: _screens,
      ),
      bottomNavigationBar: Consumer<TabNavigationProvider>(
        builder: (context, tabProvider, child) {
          return BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: tabProvider.selectedIndex,
            onTap: _onItemTapped,
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.feed),
            label: 'Hangouts',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add),
            label: 'Create',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
          );
        },
      ),
    );
  }
}