import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../utils/colors.dart';
import '../models/post_model.dart';
import '../providers/auth_provider.dart';
import '../providers/post_provider.dart';
import '../providers/tab_navigation_provider.dart';
import '../services/analytics_service.dart';
import '../widgets/invite_options_modal.dart';

enum FoodLocation {
  marcianoCommons,
  warrenTowers,
  gsu,
  raisingCanes,
  westCampus,
  other,
}

enum StudyLocation { mugar, wheelock, cgs, sci, stuviII, other }

enum FitRecActivity { lift, basketball, climb, swim, other }

class CreatePostBottomSheet extends StatefulWidget {
  final String userName;
  final PostType? initialPostType;

  const CreatePostBottomSheet({
    super.key,
    required this.userName,
    this.initialPostType,
  });

  @override
  State<CreatePostBottomSheet> createState() => _CreatePostBottomSheetState();

  static Future<void> show(
    BuildContext context,
    String userName, {
    PostType? initialPostType,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreatePostBottomSheet(
        userName: userName,
        initialPostType: initialPostType,
      ),
    );
  }
}

class _CreatePostBottomSheetState extends State<CreatePostBottomSheet> {
  PostType? _selectedType;
  Activity? _selectedActivity;
  FoodLocation? _selectedFoodLocation;
  StudyLocation? _selectedStudyLocation;
  FitRecActivity? _selectedFitRecActivity;
  String? _customActivityText;
  String? _customStudyLocationText;
  String? _customFoodLocationText;
  String? _customFitRecActivityText;
  String? _walkingFromLocation;
  String? _walkingToLocation;
  String? _chillingLocation;
  String? _customActivityLocation;
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  TimeOfDay? _selectedEndTime;
  bool _isTodaySelected = false;
  bool _isNowSelected = false;
  String? _timeErrorMessage;
  Set<String> _selectedGenderPreferences = {'Men', 'Women', 'Non-binary'};
  String? _genderPreferenceError;
  int? _maxGroupSize;
  bool _isMaxGroupSizeSelected = false;
  String? _maxGroupSizeError;
  String? _additionalDetails;
  final PageController _pageController = PageController();
  final TextEditingController _customActivityController =
      TextEditingController();
  final TextEditingController _customStudyLocationController =
      TextEditingController();
  final TextEditingController _customFoodLocationController =
      TextEditingController();
  final TextEditingController _customFitRecActivityController =
      TextEditingController();
  final TextEditingController _walkingFromController = TextEditingController();
  final TextEditingController _walkingToController = TextEditingController();
  final TextEditingController _chillingLocationController = TextEditingController();
  final TextEditingController _customActivityLocationController = TextEditingController();
  final TextEditingController _maxGroupSizeController = TextEditingController();
  final TextEditingController _detailsController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // If initial post type is provided, set it and navigate to appropriate page
    if (widget.initialPostType != null) {
      _selectedType = widget.initialPostType;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Waving skips to date selection (page 3), others go to activity selection (page 1)
        final targetPage = widget.initialPostType == PostType.waving ? 3 : 1;
        _pageController.jumpToPage(targetPage);
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _customActivityController.dispose();
    _customStudyLocationController.dispose();
    _customFoodLocationController.dispose();
    _customFitRecActivityController.dispose();
    _walkingFromController.dispose();
    _walkingToController.dispose();
    _chillingLocationController.dispose();
    _customActivityLocationController.dispose();
    _maxGroupSizeController.dispose();
    _detailsController.dispose();
    super.dispose();
  }

  void _goToNextStep(PostType type) {
    setState(() => _selectedType = type);

    // Waving skips activity and location, goes straight to when
    final targetPage = type == PostType.waving ? 3 : 1;

    _pageController.animateToPage(
      targetPage,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _goToPreviousPage() {
    if (_pageController.hasClients) {
      final currentPage = _pageController.page?.round() ?? 0;
      if (currentPage > 0) {
        int targetPage = currentPage - 1;

        // If waving and on date selection page (3), go back to type selection (0)
        if (_selectedType == PostType.waving && currentPage == 3) {
          targetPage = 0;
        }

        _pageController.animateToPage(
          targetPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  void _selectActivity(Activity activity) {
    setState(() => _selectedActivity = activity);
    _pageController.animateToPage(
      2,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _selectStudyLocation(StudyLocation location) {
    setState(() => _selectedStudyLocation = location);
    if (location != StudyLocation.other) {
      _pageController.animateToPage(
        3,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
    // If "other" is selected, stay on page to show text field
  }

  Future<void> _selectWhen({required bool isToday}) async {
    setState(() {
      _isTodaySelected = isToday;
      _timeErrorMessage = null; // Clear any previous error
    });

    if (isToday) {
      // Today: Set date to today and navigate to time selection
      setState(() => _selectedDate = DateTime.now());
      _pageController.animateToPage(
        4, // Navigate to time selection screen
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Another day: Show date picker, then navigate to time selection
      final DateTime? date = await showDatePicker(
        context: context,
        initialDate: DateTime.now().add(const Duration(days: 1)),
        firstDate: DateTime.now(), // Prevents selecting past dates
        lastDate: DateTime.now().add(const Duration(days: 365)),
      );

      if (date != null) {
        setState(() => _selectedDate = date);
        _pageController.animateToPage(
          4, // Navigate to time selection screen
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildTypeSelection(),        // 0
            _buildActivitySelection(),    // 1
            _buildLocationOrNextStep(),   // 2
            _buildWhenSelection(),        // 3 - Date selection
            _buildTimeSelection(),        // 4 - Time selection (NEW)
            _buildGenderPreferenceSelection(), // 5
            _buildMaxGroupSizeSelection(), // 6
            _buildDetailsSelection(),     // 7
            _buildFinalStep(),            // 8
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderWithBackButton(String title) {
    return Stack(
      children: [
        // Back button on the left
        Positioned(
          left: 0,
          top: 0,
          child: IconButton(
            icon: Icon(
              Icons.arrow_back,
              color: AppColors.textPrimary,
              size: 24,
            ),
            onPressed: _goToPreviousPage,
          ),
        ),
        // Centered title
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 8.0,
              horizontal: 48.0,
            ),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeSelection() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header question
            Text(
              'What\'re you up to today, ${widget.userName}?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 24),

            // Option 1: Walking
            _buildOptionCard(
              emoji: '🚶',
              text: 'I have plans and I\'m open to people joining me.',
              example:
                  'e.g. I\'m going to the dining hall and I\'d rather eat with a group.',
              type: PostType.walking,
            ),

            const SizedBox(height: 12),

            // Option 2: Raising
            _buildOptionCard(
              emoji: '🙋',
              text: 'I\'m looking for a group/another person.',
              example: 'e.g. I need people for a poker night.',
              type: PostType.raising,
            ),

            const SizedBox(height: 12),

            // Option 3: Waving
            _buildOptionCard(
              emoji: '👋',
              text: 'I\'m free and open to hanging out.',
              example:
                  'e.g. I have nothing to do tonight and want go out with a group.',
              type: PostType.waving,
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildActivitySelection() {
    // Show activity selection for walking and raising types
    if (_selectedType != PostType.walking && _selectedType != PostType.raising) {
      return _buildPlaceholder(
        'Activity selection not yet implemented for this type',
      );
    }

    // Determine header and labels based on type
    final isRaising = _selectedType == PostType.raising;
    final headerText = isRaising ? 'What do you want to do?' : 'What are you doing?';

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header with back button
            _buildHeaderWithBackButton(headerText),

            const SizedBox(height: 24),

            // Activity buttons with grammar based on type
            _buildActivityButton(
              '🍔',
              isRaising ? 'Get food' : 'Getting food',
              Activity.diningHall,
            ),
            const SizedBox(height: 12),
            _buildActivityButton(
              '📚',
              isRaising ? 'Study' : 'Studying',
              Activity.studying,
            ),
            const SizedBox(height: 12),
            _buildActivityButton(
              '🚶',
              isRaising ? 'Walk somewhere' : 'Walking somewhere',
              Activity.walking,
            ),
            const SizedBox(height: 12),
            _buildActivityButton(
              '🏋️',
              isRaising ? 'Hit FitRec' : 'Hitting FitRec',
              Activity.fitRec,
            ),
            const SizedBox(height: 12),
            _buildActivityButton(
              '😎',
              isRaising ? 'Just chill' : 'Just chilling',
              Activity.chilling,
            ),
            const SizedBox(height: 12),
            _buildOtherActivityButton(),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationOrNextStep() {
    // Show location selection for getting food activity
    if (_selectedActivity == Activity.diningHall) {
      return _buildFoodLocationSelection();
    }

    // Show location selection for studying activity
    if (_selectedActivity == Activity.studying) {
      return _buildStudyLocationSelection();
    }

    // Show activity selection for FitRec
    if (_selectedActivity == Activity.fitRec) {
      return _buildFitRecActivitySelection();
    }

    // Show from/to location for walking activity
    if (_selectedActivity == Activity.walking) {
      return _buildWalkingLocationSelection();
    }

    // Show location for chilling activity
    if (_selectedActivity == Activity.chilling) {
      return _buildChillingLocationSelection();
    }

    // Show location input for custom "other" activity
    if (_selectedActivity == Activity.other) {
      return _buildCustomActivityLocationSelection();
    }

    // For other activities, show placeholder
    return _buildPlaceholder('Next step not yet implemented for this activity');
  }

  Widget _buildFoodLocationSelection() {
    final isOtherSelected = _selectedFoodLocation == FoodLocation.other;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header with back button
            _buildHeaderWithBackButton('Where?'),

            const SizedBox(height: 24),

            // Location buttons
            _buildFoodLocationButton(
              'Marciano Commons',
              FoodLocation.marcianoCommons,
            ),
            const SizedBox(height: 12),
            _buildFoodLocationButton('Warren Towers', FoodLocation.warrenTowers),
            const SizedBox(height: 12),
            _buildFoodLocationButton('GSU', FoodLocation.gsu),
            const SizedBox(height: 12),
            _buildFoodLocationButton('Raising Cane\'s', FoodLocation.raisingCanes),
            const SizedBox(height: 12),
            _buildFoodLocationButton('West Campus', FoodLocation.westCampus),
            const SizedBox(height: 12),
            _buildFoodLocationButton('Other', FoodLocation.other),

            // Show text field if "Other" is selected
            if (isOtherSelected) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _customFoodLocationController,
                autofocus: true,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Where are you getting food?',
                  hintStyle: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.6),
                  ),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppColors.textSecondary.withValues(alpha: 0.2),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppColors.textSecondary.withValues(alpha: 0.2),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                onChanged: (value) {
                  setState(() {
                    _customFoodLocationText = value.trim().isEmpty
                        ? null
                        : value;
                  });
                },
              ),

              // Show Continue button when text is entered
              if (_customFoodLocationText != null &&
                  _customFoodLocationText!.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      _pageController.animateToPage(
                        3,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildFoodLocationButton(String label, FoodLocation location) {
    final isSelected = _selectedFoodLocation == location;

    return GestureDetector(
      onTap: () {
        setState(() => _selectedFoodLocation = location);
        if (location != FoodLocation.other) {
          _pageController.animateToPage(
            3,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.textSecondary.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: isSelected ? AppColors.primary : AppColors.textPrimary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildStudyLocationSelection() {
    final isOtherSelected = _selectedStudyLocation == StudyLocation.other;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header with back button
            _buildHeaderWithBackButton('Where?'),

            const SizedBox(height: 24),

            // Location buttons
            _buildStudyLocationButton('Mugar', StudyLocation.mugar),
            const SizedBox(height: 12),
            _buildStudyLocationButton('Wheelock', StudyLocation.wheelock),
            const SizedBox(height: 12),
            _buildStudyLocationButton('CGS', StudyLocation.cgs),
            const SizedBox(height: 12),
            _buildStudyLocationButton('SCI', StudyLocation.sci),
            const SizedBox(height: 12),
            _buildStudyLocationButton('StuVi II', StudyLocation.stuviII),
            const SizedBox(height: 12),
            _buildStudyLocationButton('Other', StudyLocation.other),

            // Show text field if "Other" is selected
            if (isOtherSelected) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _customStudyLocationController,
                autofocus: true,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Where are you studying?',
                  hintStyle: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.6),
                  ),
                  filled: true,
                  fillColor: AppColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppColors.textSecondary.withValues(alpha: 0.2),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: AppColors.textSecondary.withValues(alpha: 0.2),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: AppColors.primary, width: 2),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
                onChanged: (value) {
                  setState(() {
                    _customStudyLocationText = value.trim().isEmpty
                        ? null
                        : value;
                  });
                },
              ),

              // Show Continue button when text is entered
              if (_customStudyLocationText != null &&
                  _customStudyLocationText!.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      _pageController.animateToPage(
                        3,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildStudyLocationButton(String label, StudyLocation location) {
    final isSelected = _selectedStudyLocation == location;

    return GestureDetector(
      onTap: () => _selectStudyLocation(location),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.textSecondary.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 16,
            color: isSelected ? AppColors.primary : AppColors.textPrimary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildFitRecActivitySelection() {
    final isOtherSelected = _selectedFitRecActivity == FitRecActivity.other;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header with back button
            _buildHeaderWithBackButton(
              _selectedType == PostType.raising
                  ? 'What do you want to do at FitRec?'
                  : 'What are you doing at FitRec?',
            ),

            const SizedBox(height: 24),

            // Activity buttons
            _buildFitRecActivityButton('🏋️', 'Lift', FitRecActivity.lift),
            const SizedBox(height: 12),
            _buildFitRecActivityButton('🏀', 'Basketball', FitRecActivity.basketball),
            const SizedBox(height: 12),
            _buildFitRecActivityButton('🧗', 'Climb', FitRecActivity.climb),
            const SizedBox(height: 12),
            _buildFitRecActivityButton('🏊', 'Swim', FitRecActivity.swim),
            const SizedBox(height: 12),

            // Other button with text field
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      if (_selectedFitRecActivity == FitRecActivity.other) {
                        _selectedFitRecActivity = null;
                        _customFitRecActivityText = null;
                        _customFitRecActivityController.clear();
                      } else {
                        _selectedFitRecActivity = FitRecActivity.other;
                      }
                    });
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isOtherSelected
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isOtherSelected
                            ? AppColors.primary
                            : AppColors.textSecondary.withValues(alpha: 0.2),
                        width: isOtherSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Text('✨', style: TextStyle(fontSize: 28)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            'Other',
                            style: TextStyle(
                              fontSize: 16,
                              color: isOtherSelected
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                              fontWeight: isOtherSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Show text field when "Other" is selected
                if (isOtherSelected) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _customFitRecActivityController,
                    autofocus: true,
                    style: TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'What are you doing at FitRec?',
                      hintStyle: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.6),
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.textSecondary.withValues(alpha: 0.2),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.textSecondary.withValues(alpha: 0.2),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: AppColors.primary, width: 2),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _customFitRecActivityText = value.trim().isEmpty
                            ? null
                            : value;
                      });
                    },
                  ),

                  // Show Continue button when text is entered
                  if (_customFitRecActivityText != null &&
                      _customFitRecActivityText!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          _pageController.animateToPage(
                            3,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _selectFitRecActivity(FitRecActivity activity) {
    setState(() => _selectedFitRecActivity = activity);
    _pageController.animateToPage(
      3,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildFitRecActivityButton(String emoji, String label, FitRecActivity activity) {
    final isSelected = _selectedFitRecActivity == activity;

    return GestureDetector(
      onTap: () => _selectFitRecActivity(activity),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.textSecondary.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fitRecActivityToString(FitRecActivity activity) {
    switch (activity) {
      case FitRecActivity.lift:
        return 'Lift';
      case FitRecActivity.basketball:
        return 'Basketball';
      case FitRecActivity.climb:
        return 'Climb';
      case FitRecActivity.swim:
        return 'Swim';
      case FitRecActivity.other:
        return _customFitRecActivityText ?? 'Other';
    }
  }

  Widget _buildChillingLocationSelection() {
    final hasLocation = _chillingLocation != null && _chillingLocation!.isNotEmpty;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header with back button
            _buildHeaderWithBackButton('Where?'),

            const SizedBox(height: 24),

            // Location text field
            TextField(
              controller: _chillingLocationController,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Where are you chilling?',
                hintStyle: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.6),
                ),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppColors.textSecondary.withValues(alpha: 0.2),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppColors.textSecondary.withValues(alpha: 0.2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              onChanged: (value) {
                setState(() {
                  _chillingLocation = value.trim().isEmpty ? null : value.trim();
                });
              },
            ),

            const SizedBox(height: 24),

            // Continue button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: hasLocation
                    ? () {
                        _pageController.animateToPage(
                          3,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.textSecondary.withValues(alpha: 0.3),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomActivityLocationSelection() {
    final hasLocation = _customActivityLocation != null && _customActivityLocation!.isNotEmpty;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header with back button
            _buildHeaderWithBackButton('Where?'),

            const SizedBox(height: 24),

            // Location text field
            TextField(
              controller: _customActivityLocationController,
              autofocus: true,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Where will this be?',
                hintStyle: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.6),
                ),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppColors.textSecondary.withValues(alpha: 0.2),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppColors.textSecondary.withValues(alpha: 0.2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              onChanged: (value) {
                setState(() {
                  _customActivityLocation = value.trim().isEmpty ? null : value.trim();
                });
              },
            ),

            const SizedBox(height: 24),

            // Continue button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: hasLocation
                    ? () {
                        _pageController.animateToPage(
                          3,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.textSecondary.withValues(alpha: 0.3),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildWalkingLocationSelection() {
    final hasFromLocation = _walkingFromLocation != null && _walkingFromLocation!.isNotEmpty;
    final hasToLocation = _walkingToLocation != null && _walkingToLocation!.isNotEmpty;
    final canContinue = hasFromLocation || hasToLocation;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header with back button
            _buildHeaderWithBackButton('Where?'),

            const SizedBox(height: 24),

            // From location
            Text(
              'Where are you walking from?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _walkingFromController,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'e.g., Warren Towers',
                hintStyle: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.6),
                ),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppColors.textSecondary.withValues(alpha: 0.2),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppColors.textSecondary.withValues(alpha: 0.2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              onChanged: (value) {
                setState(() {
                  _walkingFromLocation = value.trim().isEmpty ? null : value.trim();
                });
              },
            ),

            const SizedBox(height: 20),

            // To location
            Text(
              'Where are you walking to?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _walkingToController,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'e.g., GSU',
                hintStyle: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.6),
                ),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppColors.textSecondary.withValues(alpha: 0.2),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppColors.textSecondary.withValues(alpha: 0.2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              onChanged: (value) {
                setState(() {
                  _walkingToLocation = value.trim().isEmpty ? null : value.trim();
                });
              },
            ),

            const SizedBox(height: 24),

            // Continue button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canContinue
                    ? () {
                        _pageController.animateToPage(
                          3,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.textSecondary.withValues(alpha: 0.3),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildWhenSelection() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header with back button
            _buildHeaderWithBackButton('When?'),

            const SizedBox(height: 24),

            // Today button
            GestureDetector(
              onTap: () => _selectWhen(isToday: true),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.textSecondary.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  'Today',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Another day button
            GestureDetector(
              onTap: () => _selectWhen(isToday: false),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.textSecondary.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  'Another day',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            // Error message display
            if (_timeErrorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _timeErrorMessage!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSelection() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header with back button
            _buildHeaderWithBackButton('When?'),

            const SizedBox(height: 24),

            // Now button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  setState(() {
                    if (_isNowSelected) {
                      // Deselect Now
                      _isNowSelected = false;
                      _selectedTime = null;
                    } else {
                      // Select Now
                      _isNowSelected = true;
                      _selectedTime = TimeOfDay.now();
                      _timeErrorMessage = null;
                      // Suggest end time 1 hour from now if not set
                      if (_selectedEndTime == null) {
                        final now = TimeOfDay.now();
                        _selectedEndTime = TimeOfDay(
                          hour: (now.hour + 1) % 24,
                          minute: now.minute,
                        );
                      }
                    }
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isNowSelected
                      ? AppColors.primary
                      : AppColors.surface,
                  foregroundColor: _isNowSelected
                      ? Colors.white
                      : AppColors.textPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: _isNowSelected
                          ? AppColors.primary
                          : AppColors.textSecondary.withValues(alpha: 0.2),
                      width: _isNowSelected ? 0 : 1,
                    ),
                  ),
                ),
                child: const Text(
                  'Now',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // "or" divider
            Row(
              children: [
                Expanded(
                  child: Divider(
                    color: AppColors.textSecondary.withValues(alpha: 0.2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'or',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(
                    color: AppColors.textSecondary.withValues(alpha: 0.2),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Start Time
            Text(
              'Start Time',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _isNowSelected
                    ? AppColors.textSecondary.withValues(alpha: 0.5)
                    : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _isNowSelected
                  ? null
                  : () async {
                      final TimeOfDay? time = await showTimePicker(
                        context: context,
                        initialTime: _selectedTime ?? TimeOfDay.now(),
                      );
                      if (time != null) {
                        // Validate if today
                        if (_isTodaySelected) {
                          final now = DateTime.now();
                          final selectedDateTime = DateTime(
                            now.year,
                            now.month,
                            now.day,
                            time.hour,
                            time.minute,
                          );
                          if (selectedDateTime.isBefore(now)) {
                            setState(() {
                              _timeErrorMessage =
                                  'Please select a time in the future';
                            });
                            return;
                          }
                        }
                        setState(() {
                          _selectedTime = time;
                          _isNowSelected = false;
                          _timeErrorMessage = null;
                        });
                      }
                    },
              child: Opacity(
                opacity: _isNowSelected ? 0.5 : 1.0,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _isNowSelected
                          ? AppColors.textSecondary.withValues(alpha: 0.2)
                          : (_selectedTime != null
                              ? AppColors.primary
                              : AppColors.textSecondary.withValues(alpha: 0.2)),
                      width: _selectedTime != null && !_isNowSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        color: _isNowSelected
                            ? AppColors.textSecondary.withValues(alpha: 0.5)
                            : (_selectedTime != null
                                ? AppColors.primary
                                : AppColors.textSecondary),
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        _isNowSelected
                            ? 'Now'
                            : (_selectedTime != null
                                ? _selectedTime!.format(context)
                                : 'Select start time'),
                        style: TextStyle(
                          fontSize: 16,
                          color: _isNowSelected
                              ? AppColors.textSecondary.withValues(alpha: 0.6)
                              : (_selectedTime != null
                                  ? AppColors.textPrimary
                                  : AppColors.textSecondary
                                      .withValues(alpha: 0.6)),
                          fontWeight: _selectedTime != null && !_isNowSelected
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // End Time
            Text(
              'End Time (Approximately)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'This determines when your post will be removed from the feed',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final TimeOfDay? time = await showTimePicker(
                  context: context,
                  initialTime: _selectedEndTime ??
                      (_selectedTime != null
                          ? TimeOfDay(
                              hour: (_selectedTime!.hour + 1) % 24,
                              minute: _selectedTime!.minute,
                            )
                          : TimeOfDay.now()),
                );
                if (time != null) {
                  setState(() {
                    _selectedEndTime = time;
                  });
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedEndTime != null
                        ? AppColors.primary
                        : AppColors.textSecondary.withValues(alpha: 0.2),
                    width: _selectedEndTime != null ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      color: _selectedEndTime != null
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _selectedEndTime != null
                          ? _selectedEndTime!.format(context)
                          : 'Select end time',
                      style: TextStyle(
                        fontSize: 16,
                        color: _selectedEndTime != null
                            ? AppColors.textPrimary
                            : AppColors.textSecondary.withValues(alpha: 0.6),
                        fontWeight: _selectedEndTime != null
                            ? FontWeight.w500
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Error message display
            if (_timeErrorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _timeErrorMessage!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Continue button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_isNowSelected || _selectedTime != null) &&
                        _selectedEndTime != null
                    ? () {
                        _pageController.animateToPage(
                          5, // Navigate to gender preference screen
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.textSecondary.withValues(alpha: 0.3),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _toggleGenderPreference(String gender) {
    setState(() {
      _genderPreferenceError = null; // Clear any previous error

      if (_selectedGenderPreferences.contains(gender)) {
        // Trying to deselect
        if (_selectedGenderPreferences.length == 1) {
          // Can't deselect the last one
          _genderPreferenceError = 'At least one option must be selected';
          return;
        }
        _selectedGenderPreferences.remove(gender);
      } else {
        // Selecting
        _selectedGenderPreferences.add(gender);
      }
    });
  }

  String? _validateGenderSelection() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;

    if (currentUser == null) return 'Authentication error';

    final userGender = currentUser.gender;

    // If user has no gender or prefers not to say, they must select all genders
    if (userGender == null || userGender == 'prefer_not_to_say') {
      if (_selectedGenderPreferences.length != 3 ||
          !_selectedGenderPreferences.contains('Men') ||
          !_selectedGenderPreferences.contains('Women') ||
          !_selectedGenderPreferences.contains('Non-binary')) {
        return 'Since you haven\'t specified a gender, you must include all gender options to create a hangout';
      }
      return null;
    }

    // Map user gender to required preference
    String requiredPreference;
    switch (userGender) {
      case 'woman':
        requiredPreference = 'Women';
        break;
      case 'man':
        requiredPreference = 'Men';
        break;
      case 'non_binary':
        requiredPreference = 'Non-binary';
        break;
      default:
        requiredPreference =
            'Non-binary'; // Default for other gender identities
        break;
    }

    // Check if user's gender is included in selection
    if (!_selectedGenderPreferences.contains(requiredPreference)) {
      return 'You must include your own gender ($requiredPreference) to create this hangout';
    }

    return null;
  }

  DateTime? get _selectedDateTime {
    if (_selectedDate == null || _selectedTime == null) return null;
    return DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );
  }

  String _foodLocationToString(FoodLocation location) {
    switch (location) {
      case FoodLocation.marcianoCommons:
        return 'Marciano Commons';
      case FoodLocation.warrenTowers:
        return 'Warren Towers';
      case FoodLocation.gsu:
        return 'GSU';
      case FoodLocation.raisingCanes:
        return 'Raising Cane\'s';
      case FoodLocation.westCampus:
        return 'West Campus';
      case FoodLocation.other:
        return _customFoodLocationText ?? 'Other';
    }
  }

  String _studyLocationToString(StudyLocation location) {
    switch (location) {
      case StudyLocation.mugar:
        return 'Mugar';
      case StudyLocation.wheelock:
        return 'Wheelock';
      case StudyLocation.cgs:
        return 'CGS';
      case StudyLocation.sci:
        return 'SCI';
      case StudyLocation.stuviII:
        return 'StuVi II';
      case StudyLocation.other:
        return _customStudyLocationText ?? 'Other';
    }
  }

  Future<void> _createPost() async {
    // Get providers & current user
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final postProvider = Provider.of<PostProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;

    // Validate user is authenticated
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to create a hangout'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    try {
      // Determine location based on activity type
      String? finalLocation;
      if (_selectedActivity == Activity.diningHall &&
          _selectedFoodLocation != null) {
        finalLocation = _foodLocationToString(_selectedFoodLocation!);
      } else if (_selectedActivity == Activity.studying &&
          _selectedStudyLocation != null) {
        finalLocation = _studyLocationToString(_selectedStudyLocation!);
      } else if (_selectedActivity == Activity.fitRec &&
          _selectedFitRecActivity != null) {
        finalLocation = 'FitRec - ${_fitRecActivityToString(_selectedFitRecActivity!)}';
      } else if (_selectedActivity == Activity.walking) {
        finalLocation = _walkingFromLocation;
      } else if (_selectedActivity == Activity.chilling) {
        finalLocation = _chillingLocation;
      } else if (_selectedActivity == Activity.other) {
        finalLocation = _customActivityLocation;
      }

      // Determine locationTo for walking activity
      String? finalLocationTo;
      if (_selectedActivity == Activity.walking) {
        finalLocationTo = _walkingToLocation;
      }

      // Create the hangout
      final success = await postProvider.createPost(
        type: _selectedType!,
        activity: _selectedActivity,
        customActivity: _customActivityText,
        description: _additionalDetails,
        authorId: currentUser.id,
        authorName: currentUser.displayName ?? 'Unknown User',
        authorDorm: currentUser.location,
        authorYear: currentUser.classYear,
        scheduledTime: _selectedDateTime,
        genderPreferences: _selectedGenderPreferences.toList(),
        location: finalLocation,
        locationTo: finalLocationTo,
        maxParticipants: _maxGroupSize,
      );

      // Dismiss loading dialog
      if (mounted) Navigator.of(context).pop();

      if (success) {
        // Get hangout ID and track analytics
        final hangoutId = postProvider.lastCreatedPostId ?? '';
        await AnalyticsService().trackHangoutCreated(
          userId: currentUser.id,
          hangoutId: hangoutId,
        );

        if (mounted) {
          // Close bottom sheet
          Navigator.of(context).pop();

          // Navigate to hangouts tab
          final tabProvider = Provider.of<TabNavigationProvider>(
            context,
            listen: false,
          );
          tabProvider.navigateToHangouts(tab: 'yourPosts');

          // Show success dialog with invite option
          _showSuccessWithInviteOption(
            hangoutId: hangoutId,
            inviterName: currentUser.displayName ?? 'Unknown User',
          );
        }
      } else {
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(postProvider.error ?? 'Failed to create hangout'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    } catch (e) {
      // Dismiss loading dialog
      if (mounted) Navigator.of(context).pop();

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create hangout: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  void _showSuccessWithInviteOption({
    required String hangoutId,
    required String inviterName,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.success, size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Posted!',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'You have posted successfully!',
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              'Want to invite friends to join?',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text(
              'Maybe Later',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              InviteOptionsModal.show(
                context,
                hangoutId: hangoutId,
                inviterName: inviterName,
              );
            },
            icon: const Icon(Icons.person_add, size: 18),
            label: const Text('Invite Friends'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _advanceFromGenderPreference() {
    // Validate gender selection before advancing
    final validationError = _validateGenderSelection();
    if (validationError != null) {
      setState(() {
        _genderPreferenceError = validationError;
      });
      return;
    }

    // Clear any previous error and navigate
    setState(() {
      _genderPreferenceError = null;
    });

    _pageController.animateToPage(
      6, // Navigate to max group size screen
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildGenderPreferenceSelection() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header with back button
            _buildHeaderWithBackButton('Who are you looking to hangout with?'),

            const SizedBox(height: 24),

            // Men button
            _buildGenderPreferenceButton('Men'),
            const SizedBox(height: 12),

            // Women button
            _buildGenderPreferenceButton('Women'),
            const SizedBox(height: 12),

            // Non-binary button
            _buildGenderPreferenceButton('Non-binary'),

            // Error message display
            if (_genderPreferenceError != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _genderPreferenceError!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            // Continue button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _advanceFromGenderPreference,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderPreferenceButton(String gender) {
    final isSelected = _selectedGenderPreferences.contains(gender);

    return GestureDetector(
      onTap: () => _toggleGenderPreference(gender),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.textSecondary.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Checkbox indicator
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary.withValues(alpha: 0.4),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, color: Colors.white, size: 16)
                  : null,
            ),
            const SizedBox(width: 16),
            Text(
              gender == 'Men'
                  ? '👨'
                  : gender == 'Women'
                  ? '👩'
                  : '🏳️‍🌈',
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                gender,
                style: TextStyle(
                  fontSize: 16,
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectMaxGroupSize(bool hasLimit) {
    setState(() {
      _isMaxGroupSizeSelected = hasLimit;
      _maxGroupSizeError = null; // Clear any previous error

      if (!hasLimit) {
        // User selected "No" - clear the input and navigate immediately
        _maxGroupSize = null;
        _maxGroupSizeController.clear();
        _pageController.animateToPage(
          7, // Navigate to details screen
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _validateAndAdvanceFromMaxGroupSize() {
    final text = _maxGroupSizeController.text.trim();

    if (text.isEmpty) {
      setState(() {
        _maxGroupSizeError = 'Please enter a valid number';
      });
      return;
    }

    final number = int.tryParse(text);

    if (number == null) {
      setState(() {
        _maxGroupSizeError = 'Please enter a valid number';
      });
      return;
    }

    if (number < 2 || number > 100) {
      setState(() {
        _maxGroupSizeError = 'Group size must be between 2 and 100';
      });
      return;
    }

    // Valid number
    setState(() {
      _maxGroupSize = number;
      _maxGroupSizeError = null;
    });

    _pageController.animateToPage(
      7, // Navigate to details screen
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildMaxGroupSizeSelection() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header with back button
            _buildHeaderWithBackButton('Do you want a maximum group size?'),

            const SizedBox(height: 24),

            // No button
            GestureDetector(
              onTap: () => _selectMaxGroupSize(false),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.textSecondary.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  'No',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Yes button
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GestureDetector(
                  onTap: () => _selectMaxGroupSize(true),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _isMaxGroupSizeSelected
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isMaxGroupSizeSelected
                            ? AppColors.primary
                            : AppColors.textSecondary.withValues(alpha: 0.2),
                        width: _isMaxGroupSizeSelected ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      'Yes',
                      style: TextStyle(
                        fontSize: 16,
                        color: _isMaxGroupSizeSelected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                        fontWeight: _isMaxGroupSizeSelected
                            ? FontWeight.w600
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ),

                // Show number input when "Yes" is selected
                if (_isMaxGroupSizeSelected) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _maxGroupSizeController,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Enter maximum group size (2-100)',
                      hintStyle: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.6),
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.textSecondary.withValues(alpha: 0.2),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.textSecondary.withValues(alpha: 0.2),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _maxGroupSizeError = null; // Clear error when typing
                      });
                    },
                  ),

                  // Show Continue button when text is entered
                  if (_maxGroupSizeController.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _validateAndAdvanceFromMaxGroupSize,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),

            // Error message display
            if (_maxGroupSizeError != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.red.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _maxGroupSizeError!,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailsSelection() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header with back button
            _buildHeaderWithBackButton(
              'Any details you want to share? (Optional)',
            ),

            const SizedBox(height: 24),

            // Multi-line text field for details
            TextField(
              controller: _detailsController,
              maxLines: 6,
              style: TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Add any additional details here...',
                hintStyle: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.6),
                ),
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppColors.textSecondary.withValues(alpha: 0.2),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: AppColors.textSecondary.withValues(alpha: 0.2),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.primary, width: 2),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
              onChanged: (value) {
                setState(() {
                  _additionalDetails = value.trim().isEmpty ? null : value;
                });
              },
            ),

            const SizedBox(height: 24),

            // Post button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _createPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Post',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildFinalStep() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header with back button
            _buildHeaderWithBackButton('Final Step'),

            const SizedBox(height: 16),

            Text(
              'Selected type: ${_selectedType?.name ?? "None"}',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),

            const SizedBox(height: 8),

            Text(
              'Selected activity: ${_selectedActivity == Activity.other && _customActivityText != null ? _customActivityText : _selectedActivity?.name ?? "None"}',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),

            const SizedBox(height: 8),

            Text(
              'Selected location: ${_selectedFoodLocation?.name ?? "None"}',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),

            const SizedBox(height: 8),

            Text(
              'Selected date: ${_selectedDate != null ? "${_selectedDate!.month}/${_selectedDate!.day}/${_selectedDate!.year}" : "None"}',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),

            const SizedBox(height: 8),

            Text(
              'Selected time: ${_selectedTime != null ? _selectedTime!.format(context) : "None"}',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),

            const SizedBox(height: 8),

            Text(
              'Gender preferences: ${_selectedGenderPreferences.isNotEmpty ? _selectedGenderPreferences.join(", ") : "None"}',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),

            const SizedBox(height: 8),

            Text(
              'Maximum group size: ${_maxGroupSize != null ? _maxGroupSize.toString() : "No limit"}',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Text(
          message,
          style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildActivityButton(String emoji, String text, Activity activity) {
    return GestureDetector(
      onTap: () => _selectActivity(activity),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.textSecondary.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOtherActivityButton() {
    final isOtherSelected = _selectedActivity == Activity.other;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              if (_selectedActivity == Activity.other) {
                // Deselect if already selected
                _selectedActivity = null;
                _customActivityText = null;
                _customActivityController.clear();
              } else {
                // Select "Other" but don't advance yet
                _selectedActivity = Activity.other;
              }
            });
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isOtherSelected
                  ? AppColors.primary.withValues(alpha: 0.1)
                  : AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isOtherSelected
                    ? AppColors.primary
                    : AppColors.textSecondary.withValues(alpha: 0.2),
                width: isOtherSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Text('✨', style: const TextStyle(fontSize: 28)),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'Other',
                    style: TextStyle(
                      fontSize: 16,
                      color: isOtherSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                      fontWeight: isOtherSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Show text field when "Other" is selected
        if (isOtherSelected) ...[
          const SizedBox(height: 12),
          TextField(
            controller: _customActivityController,
            autofocus: true,
            style: TextStyle(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'What are you doing?',
              hintStyle: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.6),
              ),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.textSecondary.withValues(alpha: 0.2),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.textSecondary.withValues(alpha: 0.2),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.primary, width: 2),
              ),
              contentPadding: const EdgeInsets.all(16),
            ),
            onChanged: (value) {
              setState(() {
                _customActivityText = value.trim().isEmpty ? null : value;
              });
            },
          ),

          // Show Continue button when text is entered
          if (_customActivityText != null &&
              _customActivityText!.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  _pageController.animateToPage(
                    2,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }

  Widget _buildOptionCard({
    required String emoji,
    required String text,
    required String example,
    required PostType type,
  }) {
    final isSelected = _selectedType == type;

    return GestureDetector(
      onTap: () => _goToNextStep(type),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.textSecondary.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 15,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    example,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary.withValues(alpha: 0.6),
                      fontStyle: FontStyle.italic,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
