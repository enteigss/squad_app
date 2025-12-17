import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/post_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/post_provider.dart';
import '../../providers/tab_navigation_provider.dart';
import '../../services/analytics_service.dart';
import '../../utils/colors.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/invite_options_modal.dart';
import '../../constants/bu_locations.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _customLocationController = TextEditingController();
  final _scrollController = ScrollController();

  // Keys for scrolling to error locations
  final _titleSectionKey = GlobalKey();
  final _locationSectionKey = GlobalKey();
  final _dateTimeSectionKey = GlobalKey();
  final _genderSectionKey = GlobalKey();

  DateTime? _selectedDateTime;
  Set<String> _selectedGenders = {'Men', 'Women', 'Non-binary'}; // All selected by default
  bool _showSuggestions = false;
  bool _hasParticipantLimit = false;
  int _maxParticipants = 10;
  String? _selectedLocation;
  String? _customLocation;
  bool _showLocationSearch = false;
  List<String> _filteredLocations = [];

  // Gender preference options - now fixed for all users
  final List<String> _genderPreferenceOptions = ['Men', 'Women', 'Non-binary'];

  final Map<String, List<String>> _activitySuggestions = {
    'Boston Hotspots': [
      'Exploring Newbury Street',
      'Walk along Charles River',
      'Checking out Boston Common',
      'Faneuil Hall',
      'Harvard Square',
    ],
    'BU Hotspots': ['Dining hall', 'BU Beach'],
  };

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _customLocationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Create Hangout'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            final tabProvider = Provider.of<TabNavigationProvider>(context, listen: false);
            tabProvider.navigateToHangouts();
          },
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          controller: _scrollController,
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title Section
              Container(
                key: _titleSectionKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSectionTitle('What are you planning?'),
                    const SizedBox(height: 8),
                    _buildTitleField(),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Suggestions Section
              _buildSuggestionsSection(),

              const SizedBox(height: 24),

              // Description Section
              _buildSectionTitle('Tell us more (optional)'),
              const SizedBox(height: 8),
              _buildDescriptionField(),

              const SizedBox(height: 24),

              // Location Section
              Container(
                key: _locationSectionKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSectionTitle('Where will it be?'),
                    const SizedBox(height: 8),
                    _buildLocationSelector(),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Date/Time Section
              Container(
                key: _dateTimeSectionKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSectionTitle('When will it be?'),
                    const SizedBox(height: 8),
                    _buildDateTimeSelector(),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Gender Preference Section
              Container(
                key: _genderSectionKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSectionTitle('Who are you looking to hang out with?'),
                    const SizedBox(height: 8),
                    _buildGenderSelector(),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Max Participants Section
              _buildSectionTitle('How many people can join?'),
              const SizedBox(height: 8),
              _buildMaxParticipantsSelector(),

              const SizedBox(height: 40),

              // Create Post Button
              _buildCreateButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
    );
  }

  Widget _buildTitleField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: _titleController,
        decoration: InputDecoration(
          hintText: 'Basketball at the park, coffee meetup, study session...',
          hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.7)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.all(16),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'Please enter a title for your hangout';
          }
          return null;
        },
      ),
    );
  }

  Widget _buildSuggestionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Expandable header
        GestureDetector(
          onTap: () {
            setState(() {
              _showSuggestions = !_showSuggestions;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  size: 18,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Need inspiration? Tap for suggestions',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                Icon(
                  _showSuggestions ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.primary,
                  size: 20,
                ),
              ],
            ),
          ),
        ),

        // Expandable suggestions content
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: _showSuggestions
              ? _buildSuggestionsContent()
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildSuggestionsContent() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Popular activity ideas:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ),
          ..._activitySuggestions.entries.map((category) {
            return _buildSuggestionCategory(category.key, category.value);
          }).toList(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSuggestionCategory(
    String categoryName,
    List<String> suggestions,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            categoryName,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: suggestions.map((suggestion) {
              return GestureDetector(
                onTap: () => _applySuggestion(suggestion),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    suggestion,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildDescriptionField() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: _descriptionController,
        maxLines: 4,
        decoration: InputDecoration(
          hintText:
              'Share more details about your plans...',
          hintStyle: TextStyle(color: AppColors.textSecondary.withValues(alpha: 0.7)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  Widget _buildDateTimeSelector() {
    return Column(
      children: [
        // "Now" option button
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: InkWell(
            onTap: _selectNow,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.flash_on, color: AppColors.primary, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Now (ongoing)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  if (_selectedDateTime != null && _isNow(_selectedDateTime!))
                    Icon(
                      Icons.check_circle,
                      color: AppColors.primary,
                      size: 20,
                    ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Schedule for later option
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: InkWell(
            onTap: _selectDateTime,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.access_time, color: AppColors.primary, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedDateTime == null ||
                                  _isNow(_selectedDateTime!)
                              ? 'Schedule for later'
                              : _formatDateTime(_selectedDateTime!),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color:
                                (_selectedDateTime == null ||
                                    _isNow(_selectedDateTime!))
                                ? AppColors.textSecondary.withValues(alpha: 0.7)
                                : AppColors.textPrimary,
                          ),
                        ),
                        if (_selectedDateTime != null &&
                            !_isNow(_selectedDateTime!))
                          Text(
                            _formatRelativeTime(_selectedDateTime!),
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      if (_selectedDateTime != null &&
                          !_isNow(_selectedDateTime!))
                        Icon(
                          Icons.check_circle,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      const SizedBox(width: 8),
                      Icon(Icons.chevron_right, color: AppColors.textSecondary),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people, color: AppColors.primary, size: 24),
              const SizedBox(width: 12),
              Text(
                'Gender preference',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Select who can join this hangout (multiple allowed)',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: AppColors.textSecondary.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Note: This cannot be changed after creating the hangout',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _genderPreferenceOptions.map((option) {
              final isSelected = _selectedGenders.contains(option);
              return GestureDetector(
                onTap: () => _toggleGenderSelection(option),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textSecondary.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isSelected)
                        Icon(
                          Icons.check,
                          color: Colors.white,
                          size: 16,
                        ),
                      if (isSelected) const SizedBox(width: 4),
                      Text(
                        option,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          if (_selectedGenders.length == 3)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'All genders selected - everyone can join!',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLocationSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Main location selector
          InkWell(
            onTap: () {
              setState(() {
                _showLocationSearch = !_showLocationSearch;
                if (_showLocationSearch) {
                  _filteredLocations = BULocations.allLocations;
                }
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.location_on, color: AppColors.primary, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Location',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          BULocations.getDisplayText(_selectedLocation, _customLocation),
                          style: TextStyle(
                            fontSize: 14,
                            color: _selectedLocation == null 
                                ? AppColors.textSecondary.withValues(alpha: 0.7)
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      if (_selectedLocation != null)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedLocation = null;
                              _customLocation = null;
                              _customLocationController.clear();
                            });
                          },
                          child: Icon(
                            Icons.clear,
                            color: AppColors.textSecondary,
                            size: 20,
                          ),
                        ),
                      const SizedBox(width: 8),
                      Icon(
                        _showLocationSearch ? Icons.expand_less : Icons.expand_more,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          // Expandable location search
          if (_showLocationSearch) ...[
            const Divider(height: 1),
            _buildLocationSearchContent(),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationSearchContent() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search field
          TextField(
            decoration: InputDecoration(
              hintText: 'Search locations...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: AppColors.textSecondary.withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.primary),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
            ),
            onChanged: _filterLocations,
          ),
          const SizedBox(height: 16),
          
          // Other option first
          if (_filteredLocations.contains(BULocations.otherOption))
            _buildLocationCategory('Custom', [BULocations.otherOption]),
          
          // Location categories
          ...BULocations.locationsByCategory.entries.map((category) {
            final categoryLocations = _filteredLocations
                .where((location) => category.value.contains(location))
                .toList();
            
            if (categoryLocations.isEmpty) return const SizedBox.shrink();
            
            return _buildLocationCategory(category.key, categoryLocations);
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildLocationCategory(String categoryName, List<String> locations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          categoryName,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        ...locations.map((location) {
          return InkWell(
            onTap: () => _selectLocation(location),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: _selectedLocation == location 
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _selectedLocation == location 
                      ? AppColors.primary.withValues(alpha: 0.3)
                      : Colors.transparent,
                ),
              ),
              child: Text(
                location,
                style: TextStyle(
                  color: _selectedLocation == location 
                      ? AppColors.primary
                      : AppColors.textPrimary,
                  fontWeight: _selectedLocation == location 
                      ? FontWeight.w500
                      : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildMaxParticipantsSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.group, color: AppColors.primary, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Set participant limit?',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Switch(
                value: _hasParticipantLimit,
                onChanged: (value) {
                  setState(() {
                    _hasParticipantLimit = value;
                  });
                },
                activeColor: AppColors.primary,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _hasParticipantLimit
                ? 'Your hangout will close when the limit is reached'
                : 'No limit - anyone can join (up to 100 people)',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontStyle: FontStyle.italic,
            ),
          ),
          if (_hasParticipantLimit) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                // Decrease button
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    onPressed: _maxParticipants > 2 ? _decreaseMaxParticipants : null,
                    icon: Icon(
                      Icons.remove,
                      color: _maxParticipants > 2
                          ? AppColors.primary
                          : AppColors.textSecondary.withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                ),
                const SizedBox(width: 16),
                // Number display
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '$_maxParticipants people',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Increase button
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    onPressed: _maxParticipants < 100 ? _increaseMaxParticipants : null,
                    icon: Icon(
                      Icons.add,
                      color: _maxParticipants < 100
                          ? AppColors.primary
                          : AppColors.textSecondary.withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.all(8),
                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCreateButton() {
    return CustomButton(
      text: 'Create Hangout',
      onPressed: _createPost,
      width: double.infinity,
      height: 56,
    );
  }

  void _selectNow() {
    setState(() {
      _selectedDateTime = DateTime.now();
    });
  }

  bool _isNow(DateTime dateTime) {
    final now = DateTime.now();
    final diffInMinutes = dateTime.difference(now).inMinutes.abs();
    return diffInMinutes < 1; // Consider as "now" if within 1 minute
  }

  Future<void> _selectDateTime() async {
    final now = DateTime.now();

    // Select date first
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(
              context,
            ).colorScheme.copyWith(primary: AppColors.primary),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate != null && mounted) {
      // Then select time
      final selectedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(
                context,
              ).colorScheme.copyWith(primary: AppColors.primary),
            ),
            child: child!,
          );
        },
      );

      if (selectedTime != null) {
        setState(() {
          _selectedDateTime = DateTime(
            selectedDate.year,
            selectedDate.month,
            selectedDate.day,
            selectedTime.hour,
            selectedTime.minute,
          );
        });
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final selectedDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    String dateStr;
    if (selectedDate == today) {
      dateStr = 'Today';
    } else if (selectedDate == tomorrow) {
      dateStr = 'Tomorrow';
    } else {
      dateStr = '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }

    // Convert to 12-hour format with AM/PM
    int hour = dateTime.hour;
    String period = hour >= 12 ? 'PM' : 'AM';
    if (hour == 0) {
      hour = 12; // 12 AM
    } else if (hour > 12) {
      hour = hour - 12; // Convert to 12-hour format
    }

    final timeStr =
        '$hour:${dateTime.minute.toString().padLeft(2, '0')} $period';
    return '$dateStr at $timeStr';
  }

  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = dateTime.difference(now);

    if (difference.inMinutes < 60) {
      return 'in ${difference.inMinutes} minutes';
    } else if (difference.inHours < 24) {
      return 'in ${difference.inHours} hours';
    } else {
      return 'in ${difference.inDays} days';
    }
  }

  void _applySuggestion(String suggestion) {
    setState(() {
      _titleController.text = suggestion;
      _showSuggestions = false; // Auto-collapse after selection
    });
  }

  void _toggleGenderSelection(String gender) {
    setState(() {
      if (_selectedGenders.contains(gender)) {
        // Don't allow deselecting if it's the last one
        if (_selectedGenders.length > 1) {
          _selectedGenders.remove(gender);
        }
      } else {
        _selectedGenders.add(gender);
      }
    });
  }

  void _increaseMaxParticipants() {
    if (_maxParticipants < 100) {
      setState(() {
        _maxParticipants++;
      });
    }
  }

  void _decreaseMaxParticipants() {
    if (_maxParticipants > 2) {
      setState(() {
        _maxParticipants--;
      });
    }
  }

  void _filterLocations(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredLocations = BULocations.allLocations;
      } else {
        _filteredLocations = BULocations.allLocations
            .where((location) => 
                location.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _selectLocation(String location) {
    setState(() {
      _selectedLocation = location;
      _showLocationSearch = false;
      
      // If "Other" is selected, show custom input dialog
      if (BULocations.isOtherOption(location)) {
        _showCustomLocationDialog();
      }
    });
  }

  Future<void> _showCustomLocationDialog() async {
    _customLocationController.text = _customLocation ?? '';
    
    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Custom Location'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Enter your custom hangout location:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _customLocationController,
                decoration: InputDecoration(
                  hintText: 'e.g., Starbucks on Comm Ave',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: AppColors.primary),
                  ),
                ),
                autofocus: true,
                maxLength: 100,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(null);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final customText = _customLocationController.text.trim();
                Navigator.of(context).pop(customText.isNotEmpty ? customText : null);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (result != null) {
      setState(() {
        _customLocation = result;
      });
    } else {
      // User cancelled, clear the "Other" selection
      setState(() {
        _selectedLocation = null;
        _customLocation = null;
      });
    }
  }

  String? _validateGenderSelection() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUser = authProvider.currentUser;
    
    if (currentUser == null) return 'Authentication error';
    
    final userGender = currentUser.gender;
    
    // If user has no gender or prefers not to say, they must select all genders
    if (userGender == null || userGender == 'prefer_not_to_say') {
      if (_selectedGenders.length != 3 || 
          !_selectedGenders.contains('Men') || 
          !_selectedGenders.contains('Women') || 
          !_selectedGenders.contains('Non-binary')) {
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
        requiredPreference = 'Non-binary'; // Default for other gender identities
        break;
    }
    
    // Check if user's gender is included in selection
    if (!_selectedGenders.contains(requiredPreference)) {
      return 'You must include your own gender ($requiredPreference) to create this hangout';
    }
    
    return null;
  }

  void _scrollToError(GlobalKey sectionKey) {
    final context = sectionKey.currentContext;
    if (context != null) {
      final RenderBox renderBox = context.findRenderObject() as RenderBox;
      final position = renderBox.localToGlobal(Offset.zero);

      _scrollController.animateTo(
        _scrollController.offset + position.dy - 100, // 100px offset for padding
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _createPost() async {
    if (!_formKey.currentState!.validate()) {
      // Form validation failed - scroll to title field (first error)
      _scrollToError(_titleSectionKey);
      return;
    }

    // Validate gender selection first
    final genderValidationError = _validateGenderSelection();
    if (genderValidationError != null) {
      _scrollToError(_genderSectionKey);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(genderValidationError),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    if (_selectedDateTime == null) {
      _scrollToError(_dateTimeSectionKey);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a date and time'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final now = DateTime.now();
    // Allow "now" hangouts or future hangouts, but not past hangouts (unless it's "now")
    if (_selectedDateTime!.isBefore(now) && !_isNow(_selectedDateTime!)) {
      _scrollToError(_dateTimeSectionKey);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a future date and time, or choose "Now"',
          ),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Get user information
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final postProvider = Provider.of<PostProvider>(context, listen: false);

    final currentUser = authProvider.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be logged in to create a hangout'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    try {
      // Determine the final location value
      String? finalLocation;
      if (_selectedLocation != null) {
        if (BULocations.isOtherOption(_selectedLocation!)) {
          finalLocation = _customLocation;
        } else {
          finalLocation = _selectedLocation;
        }
      }

      // Create the hangout
      final success = await postProvider.createPost(
        type: PostType.waving,
        description: _descriptionController.text.trim(),
        authorId: currentUser.id,
        authorName: currentUser.displayName ?? 'Unknown User',
        scheduledTime: _selectedDateTime!,
        genderPreferences: _selectedGenders.toList(),
        maxParticipants: _hasParticipantLimit ? _maxParticipants : null,
        location: finalLocation,
      );

      // Dismiss loading dialog
      if (mounted) Navigator.of(context).pop();

      if (success) {
        // Get hangout ID and track hangout creation in analytics
        final hangoutId = postProvider.lastCreatedPostId ?? '';
        await AnalyticsService().trackHangoutCreated(
          userId: currentUser.id,
          hangoutId: hangoutId,
        );

        // Navigate back to hangouts page first
        if (mounted) {
          print(
            'DEBUG: Hangout created successfully, navigating to hangouts page',
          );
          // Switch to the hangouts tab (index 0) using provider and show "yourPosts" tab
          final tabProvider = Provider.of<TabNavigationProvider>(context, listen: false);
          tabProvider.navigateToHangouts(tab: 'yourPosts');

          // Then show success message with invite option on hangouts page
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
                'Hangout Created!',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your hangout has been created successfully!',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              'Want to invite friends to join?',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              print(
                'DEBUG: Maybe Later button pressed - closing success dialog',
              );
              Navigator.of(context).pop(); // Just close the dialog
            },
            child: const Text(
              'Maybe Later',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              print(
                'DEBUG: Invite Friends button pressed - closing success dialog and opening invite modal',
              );
              Navigator.of(context).pop(); // Close success dialog
              InviteOptionsModal.show(
                context,
                hangoutId: hangoutId,
                inviterName: inviterName,
              );
              // No .then() callback needed - user is already on hangouts page
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
}
