import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/post_provider.dart';
import '../../utils/colors.dart';
import '../../widgets/custom_button.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime? _selectedDateTime;
  Set<String> _selectedGenders = {'Anyone'};
  bool _showSuggestions = false;

  final List<String> _genderOptions = [
    'Anyone',
    'Male',
    'Female',
    'Non-binary',
  ];

  final Map<String, List<String>> _activitySuggestions = {
    'Boston Hotspots': [
      'Exploring Newbury Street',
      'Walk along Charles River',
      'Checking out Boston Common',
      'Faneuil Hall',
      'Harvard Square',
    ],
    'BU Hotspots': [
      'Dining hall',
      'BU Beach',
    ],
  };

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Create Post'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title Section
              _buildSectionTitle('What are you planning?'),
              const SizedBox(height: 8),
              _buildTitleField(),

              const SizedBox(height: 12),

              // Suggestions Section
              _buildSuggestionsSection(),

              const SizedBox(height: 24),

              // Description Section
              _buildSectionTitle('Tell us more (optional)'),
              const SizedBox(height: 8),
              _buildDescriptionField(),

              const SizedBox(height: 24),

              // Date/Time Section
              _buildSectionTitle('When will it be?'),
              const SizedBox(height: 8),
              _buildDateTimeSelector(),

              const SizedBox(height: 24),

              // Gender Preference Section
              _buildSectionTitle('Who are you looking to hang out with?'),
              const SizedBox(height: 8),
              _buildGenderSelector(),

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
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: _titleController,
        decoration: InputDecoration(
          hintText: 'Basketball at the park, coffee meetup, study session...',
          hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.7)),
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
            return 'Please enter a title for your post';
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
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextFormField(
        controller: _descriptionController,
        maxLines: 4,
        decoration: InputDecoration(
          hintText: 'Share more details about your plans...',
          hintStyle: TextStyle(color: AppColors.textSecondary.withOpacity(0.7)),
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
                color: Colors.black.withOpacity(0.05),
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
                color: Colors.black.withOpacity(0.05),
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
                                ? AppColors.textSecondary.withOpacity(0.7)
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
            color: Colors.black.withOpacity(0.05),
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
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _genderOptions.map((option) {
              final isSelected = _selectedGenders.contains(option);
              return GestureDetector(
                onTap: () => _toggleGenderSelection(option),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textSecondary.withOpacity(0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Text(
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
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateButton() {
    return CustomButton(
      text: 'Create Post',
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

    final timeStr =
        '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
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
      if (gender == 'Anyone') {
        // If "Anyone" is selected, clear all others and select only "Anyone"
        _selectedGenders.clear();
        _selectedGenders.add('Anyone');
      } else {
        // If a specific gender is selected, remove "Anyone" first
        _selectedGenders.remove('Anyone');

        // Then toggle the selected gender
        if (_selectedGenders.contains(gender)) {
          _selectedGenders.remove(gender);
        } else {
          _selectedGenders.add(gender);
        }

        // If no specific genders are selected, default back to "Anyone"
        if (_selectedGenders.isEmpty) {
          _selectedGenders.add('Anyone');
        }
      }
    });
  }

  Future<void> _createPost() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedDateTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a date and time'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }

      final now = DateTime.now();
      // Allow "now" posts or future posts, but not past posts (unless it's "now")
      if (_selectedDateTime!.isBefore(now) && !_isNow(_selectedDateTime!)) {
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
            content: Text('You must be logged in to create a post'),
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
        // Create the post
        final success = await postProvider.createPost(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          authorId: currentUser.id,
          authorName: currentUser.displayName ?? 'Unknown User',
          scheduledTime: _selectedDateTime!,
          genderPreferences: _selectedGenders.toList(),
        );

        // Dismiss loading dialog
        if (mounted) Navigator.of(context).pop();

        if (success) {
          // Show success message and navigate back
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Post "${_titleController.text.trim()}" created successfully!',
                ),
                backgroundColor: AppColors.success,
              ),
            );
            context.pop();
          }
        } else {
          // Show error message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(postProvider.error ?? 'Failed to create post'),
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
              content: Text('Failed to create post: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      }
    }
  }
}
