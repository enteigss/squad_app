import 'package:flutter/material.dart';
import '../utils/colors.dart';

enum PostType { walking, raising, waving }

enum Activity { diningHall, studying, walking, fitRec, chilling, other }

enum FoodLocation {
  marcianoCommons,
  warrenTowers,
  gsu,
  raisingCanes,
  westCampus,
  other
}

class CreatePostBottomSheet extends StatefulWidget {
  final String userName;

  const CreatePostBottomSheet({super.key, required this.userName});

  @override
  State<CreatePostBottomSheet> createState() => _CreatePostBottomSheetState();

  static Future<void> show(BuildContext context, String userName) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreatePostBottomSheet(userName: userName),
    );
  }
}

class _CreatePostBottomSheetState extends State<CreatePostBottomSheet> {
  PostType? _selectedType;
  Activity? _selectedActivity;
  FoodLocation? _selectedFoodLocation;
  final PageController _pageController = PageController();

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToNextStep(PostType type) {
    setState(() => _selectedType = type);
    _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _selectActivity(Activity activity) {
    setState(() => _selectedActivity = activity);
    _pageController.animateToPage(
      2,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _selectFoodLocation(FoodLocation location) {
    setState(() => _selectedFoodLocation = location);
    _pageController.animateToPage(
      3,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
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
            _buildTypeSelection(),
            _buildActivitySelection(),
            _buildLocationOrNextStep(),
            _buildFinalStep(),
          ],
        ),
      ),
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
    // Only show activity selection for walking type
    if (_selectedType != PostType.walking) {
      return _buildPlaceholder(
        'Activity selection not yet implemented for this type',
      );
    }

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

            // Header question
            Text(
              'What are you doing?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 24),

            // Activity buttons
            _buildActivityButton('🍔', 'Getting food', Activity.diningHall),
            const SizedBox(height: 12),
            _buildActivityButton('📚', 'Studying', Activity.studying),
            const SizedBox(height: 12),
            _buildActivityButton('🚶', 'Walking somewhere', Activity.walking),
            const SizedBox(height: 12),
            _buildActivityButton('🏋️', 'Hitting FitRec', Activity.fitRec),
            const SizedBox(height: 12),
            _buildActivityButton('😎', 'Just chilling', Activity.chilling),
            const SizedBox(height: 12),
            _buildActivityButton('✨', 'Other', Activity.other),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationOrNextStep() {
    // Show location selection only for getting food activity
    if (_selectedActivity == Activity.diningHall) {
      return _buildFoodLocationSelection();
    }

    // For other activities, show placeholder
    return _buildPlaceholder('Next step not yet implemented for this activity');
  }

  Widget _buildFoodLocationSelection() {
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

            // Header question
            Text(
              'Where?',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 24),

            // Location buttons
            _buildLocationButton('Marciano Commons', FoodLocation.marcianoCommons),
            const SizedBox(height: 12),
            _buildLocationButton('Warren Towers', FoodLocation.warrenTowers),
            const SizedBox(height: 12),
            _buildLocationButton('GSU', FoodLocation.gsu),
            const SizedBox(height: 12),
            _buildLocationButton('Raising Cane\'s', FoodLocation.raisingCanes),
            const SizedBox(height: 12),
            _buildLocationButton('West Campus', FoodLocation.westCampus),
            const SizedBox(height: 12),
            _buildLocationButton('Other', FoodLocation.other),

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

            // Placeholder for final step
            Text(
              'Final Step',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),

            const SizedBox(height: 16),

            Text(
              'Selected type: ${_selectedType?.name ?? "None"}',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),

            const SizedBox(height: 8),

            Text(
              'Selected activity: ${_selectedActivity?.name ?? "None"}',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),

            const SizedBox(height: 8),

            Text(
              'Selected location: ${_selectedFoodLocation?.name ?? "None"}',
              style: TextStyle(fontSize: 16, color: AppColors.textSecondary),
            ),

            // TODO: Add final step content here
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

  Widget _buildLocationButton(String text, FoodLocation location) {
    return GestureDetector(
      onTap: () => _selectFoodLocation(location),
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
          text,
          style: TextStyle(
            fontSize: 16,
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
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
