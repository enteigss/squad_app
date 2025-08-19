import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../providers/post_provider.dart';
import '../../utils/colors.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/invite_options_modal.dart';

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
  String _selectedGender = 'Anyone';
  bool _showSuggestions = false;

  // Dynamic gender preference options based on user's gender
  List<String> _getGenderPreferenceOptions(String? userGender) {
    if (userGender == null || userGender == 'prefer_not_to_say') {
      return [
        'Anyone',
      ]; // Only "Anyone" if user hasn't selected gender or prefers not to say
    }

    final baseOptions = ['Anyone'];

    // Add gender-specific option based on user's selection
    switch (userGender) {
      case 'woman':
        baseOptions.insert(0, 'Women only');
        break;
      case 'man':
        baseOptions.insert(0, 'Men only');
        break;
      case 'non_binary':
        baseOptions.insert(0, 'Non-binary only');
        break;
    }

    return baseOptions;
  }

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
          hintText:
              'Share more details about your plans (e.g., "watching rick and morty in our dorm pu to room ___")...',
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
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final userGender = authProvider.currentUser?.gender;
        final genderOptions = _getGenderPreferenceOptions(userGender);

        // If user hasn't selected gender or prefers not to say, don't show the section
        if (userGender == null || userGender == 'prefer_not_to_say') {
          return const SizedBox.shrink();
        }

        // Reset selected gender if it's not in the new options
        if (!genderOptions.contains(_selectedGender)) {
          _selectedGender = genderOptions.first;
        }

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
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: genderOptions.map((option) {
                  final isSelected = _selectedGender == option;
                  return GestureDetector(
                    onTap: () => _setGenderSelection(option),
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
      },
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

  void _setGenderSelection(String gender) {
    setState(() {
      _selectedGender = gender;
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
      // Allow "now" hangouts or future hangouts, but not past hangouts (unless it's "now")
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
        // Create the hangout
        final success = await postProvider.createPost(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          authorId: currentUser.id,
          authorName: currentUser.displayName ?? 'Unknown User',
          scheduledTime: _selectedDateTime!,
          genderPreferences: [_selectedGender],
        );

        // Dismiss loading dialog
        if (mounted) Navigator.of(context).pop();

        if (success) {
          // Show success message with invite option
          if (mounted) {
            _showSuccessWithInviteOption(
              hangoutTitle: _titleController.text.trim(),
              hangoutId: postProvider.lastCreatedPostId ?? '',
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
  }

  void _showSuccessWithInviteOption({
    required String hangoutTitle,
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
              '"$hangoutTitle" has been created successfully!',
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
              Navigator.of(context).pop();
              context.pop(); // Go back to feed
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
                hangoutTitle: hangoutTitle,
                inviterName: inviterName,
              ).then((_) {
                // Navigate back to feed after invite flow - check if context is still mounted
                if (context.mounted) {
                  context.pop();
                }
              });
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
