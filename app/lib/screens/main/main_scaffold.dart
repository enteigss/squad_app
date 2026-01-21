import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/post_provider.dart';
import '../../providers/tab_navigation_provider.dart';
import '../../models/meetup_feedback.dart';
import '../../services/feedback_service.dart';
import '../../services/analytics_service.dart';
import '../../widgets/meetup_outcome_dialog.dart';
import '../feed/feed_screen.dart';
import '../plans/plans_screen.dart';
import '../profile/profile_screen.dart';
import '../connect/connect_screen.dart';

class MainScaffold extends StatefulWidget {
  final int initialIndex;

  const MainScaffold({super.key, this.initialIndex = 0});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  late PageController _pageController;
  final FeedbackService _feedbackService = FeedbackService();

  bool _hasInitializedFeedback = false;
  bool _isShowingFeedbackDialog = false;
  List<PendingFeedbackPrompt> _pendingPrompts = [];

  final List<Widget> _screens = [
    const FeedScreen(),
    const ProfileScreen(),
    const PlansScreen(),
    const ConnectScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);

    // Set initial tab in provider after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tabProvider = Provider.of<TabNavigationProvider>(
        context,
        listen: false,
      );
      tabProvider.setSelectedIndex(widget.initialIndex);
      tabProvider.addListener(_onTabChangeByProvider);
    });

    // Initialize providers and feedback after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeProviders();
      _initializeFeedbackPrompts();
    });
  }

  void _onTabChangeByProvider() {
    final tabProvider = Provider.of<TabNavigationProvider>(
      context,
      listen: false,
    );
    if (_pageController.page?.round() != tabProvider.selectedIndex) {
      _pageController.animateToPage(
        tabProvider.selectedIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _initializeProviders() {
    if (mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (authProvider.isAuthenticated && authProvider.currentUser != null) {
        final currentUserId = authProvider.currentUser!.id;
        debugPrint(
          'MainScaffold: Initializing providers for userId: $currentUserId',
        );

        // Initialize PostProvider with user ID for automatic Firestore sync
        final postProvider = Provider.of<PostProvider>(context, listen: false);
        postProvider.initializeForUser(currentUserId);
        debugPrint(
          'MainScaffold: Initialized PostProvider with Firestore listener',
        );
      }
    }
  }

  void _initializeFeedbackPrompts() async {
    if (!_hasInitializedFeedback && mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      if (authProvider.isAuthenticated && authProvider.currentUser != null) {
        final currentUserId = authProvider.currentUser!.id;
        debugPrint(
          'MainScaffold: Initializing feedback for userId: $currentUserId',
        );
        _hasInitializedFeedback = true;

        // Fetch all pending prompts once at login
        await _loadPendingFeedbackPrompts(currentUserId);
      }
    }
  }

  Future<void> _loadPendingFeedbackPrompts(String userId) async {
    try {
      debugPrint(
        'MainScaffold: Loading pending feedback prompts for userId: $userId',
      );

      // Get the stream once and take the first emission (current state)
      final prompts = await _feedbackService
          .getPendingFeedbackPrompts(userId)
          .first;

      setState(() {
        _pendingPrompts = List.from(prompts);
      });

      debugPrint(
        'MainScaffold: Loaded ${_pendingPrompts.length} pending prompts',
      );

      // Show the first prompt if any exist
      _showNextPromptIfAvailable();
    } catch (error) {
      debugPrint('MainScaffold: Error loading pending prompts: $error');
    }
  }

  void _showNextPromptIfAvailable() {
    if (_pendingPrompts.isNotEmpty && !_isShowingFeedbackDialog) {
      final nextPrompt = _pendingPrompts.first;
      debugPrint('MainScaffold: Showing next prompt: ${nextPrompt.id}');
      _showFeedbackPrompt(nextPrompt);
    } else {
      debugPrint(
        'MainScaffold: No more prompts to show. Queue length: ${_pendingPrompts.length}, Dialog showing: $_isShowingFeedbackDialog',
      );
    }
  }

  void _showFeedbackPrompt(PendingFeedbackPrompt prompt) {
    _isShowingFeedbackDialog = true;

    debugPrint(
      'MainScaffold: Showing required feedback dialog for prompt ${prompt.id}',
    );

    MeetupOutcomeDialog.show(
      context,
      contextText: 'Please let us know how your hangout went',
      actionButtonText: 'Submit Feedback',
      headerIcon: Icons.feedback_outlined,
      headerColor: AppColors.primary,
      isRequired: true,
      // No onCancel callback - this makes the prompt non-dismissible
      onConfirmDelete: (didMeetup) async {
        try {
          // Track meetup feedback
          await AnalyticsService().trackMeetupSuccess(
            didMeetup: didMeetup,
            hangoutId: prompt.hangoutId,
          );

          // Submit feedback to Firestore (this also deletes the prompt)
          await _feedbackService.submitFeedback(
            hangoutId: prompt.hangoutId,
            userId: prompt.userId,
            didMeetup: didMeetup,
            additionalFeedback: null,
          );

          debugPrint(
            'MainScaffold: Feedback submitted successfully for prompt ${prompt.id}',
          );

          // Remove from local queue immediately
          setState(() {
            _pendingPrompts.removeWhere((p) => p.id == prompt.id);
          });

          _isShowingFeedbackDialog = false;
          debugPrint(
            'MainScaffold: Removed prompt from local queue. Remaining prompts: ${_pendingPrompts.length}',
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  didMeetup
                      ? 'Thanks for the feedback! Glad your hangout was successful! 🎉'
                      : 'Thanks for the feedback! We\'ll work on improving the experience.',
                ),
                backgroundColor: didMeetup
                    ? AppColors.success
                    : AppColors.primary,
              ),
            );

            // Show next prompt immediately if available
            _showNextPromptIfAvailable();
          }
        } catch (e) {
          _isShowingFeedbackDialog = false;
          debugPrint('MainScaffold: Failed to submit feedback: $e');
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
    _pageController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    final tabProvider = Provider.of<TabNavigationProvider>(
      context,
      listen: false,
    );
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
          final tabProvider = Provider.of<TabNavigationProvider>(
            context,
            listen: false,
          );
          tabProvider.setSelectedIndex(index);
        },
        children: _screens,
      ),
      bottomNavigationBar: Consumer<TabNavigationProvider>(
        builder: (context, tabProvider, child) {
          return BottomAppBar(
            color: AppColors.surface,
            child: Container(
              height: 60.0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: <Widget>[
                  // TAB 0: HOME
                  _buildTabItem(
                    context: context,
                    tabProvider: tabProvider,
                    index: 0,
                    icon: Icons.home,
                    label: 'Home',
                  ),
                  // TAB 1: PROFILE
                  _buildTabItem(
                    context: context,
                    tabProvider: tabProvider,
                    index: 1,
                    icon: Icons.person,
                    label: 'Profile',
                  ),
                  // TAB 2: PLANS
                  _buildTabItem(
                    context: context,
                    tabProvider: tabProvider,
                    index: 2,
                    icon: Icons.event_note,
                    label: 'Plans',
                  ),
                  // TAB 3: CONNECT
                  _buildTabItem(
                    context: context,
                    tabProvider: tabProvider,
                    index: 3,
                    icon: Icons.people,
                    label: 'Connect',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabItem({
    required BuildContext context,
    required TabNavigationProvider tabProvider,
    required int index,
    required IconData icon,
    required String label,
  }) {
    final bool isSelected = tabProvider.selectedIndex == index;
    final Color color = isSelected
        ? AppColors.primary
        : AppColors.textSecondary;

    return Expanded(
      child: InkWell(
        onTap: () => _onItemTapped(index),
        customBorder: const CircleBorder(),
        child: SizedBox(
          height: 60.0,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 4.0),
              Text(label, style: TextStyle(color: color, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}
