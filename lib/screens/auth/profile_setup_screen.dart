import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_button.dart';
import '../../utils/colors.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  String? _selectedClassYear;
  final _locationController = TextEditingController();
  final _aboutController = TextEditingController();
  final _interestController = TextEditingController();

  bool _isLoading = false;
  List<String> _interests = [];
  String? _selectedGender;
  

  final List<String> _classYearOptions = [
    'Freshman',
    'Sophomore',
    'Junior',
    'Senior',
    'Graduate',
  ];

  final List<String> _popularInterests = [
    'Sports',
    'Music',
    'Movies',
    'Reading',
    'Gaming',
    'Travel',
    'Cooking',
    'Photography',
    'Art',
    'Dancing',
    'Fitness',
    'Technology',
    'Fashion',
    'Nature',
    'Animals',
    'Food',
    'Science',
    'History',
    'Writing',
    'Yoga',
  ];

  final List<Map<String, String>> _genderOptions = [
    {'value': 'woman', 'label': 'Woman'},
    {'value': 'man', 'label': 'Man'},
    {'value': 'non_binary', 'label': 'Non-binary'},
    {'value': 'prefer_not_to_say', 'label': 'Prefer not to say'},
  ];


  @override
  void dispose() {
    _fullNameController.dispose();
    // No need to dispose _selectedClassYear as it's not a controller
    _locationController.dispose();
    _aboutController.dispose();
    _interestController.dispose();
    super.dispose();
  }

  void _addInterest(String interest) {
    if (interest.isNotEmpty && !_interests.contains(interest)) {
      setState(() {
        _interests.add(interest);
        _interestController.clear();
      });
    }
  }

  void _removeInterest(String interest) {
    setState(() {
      _interests.remove(interest);
    });
  }

  Widget _buildClassYearSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Class Year',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedClassYear,
            decoration: InputDecoration(
              hintText: 'Select your class year',
              hintStyle: TextStyle(color: AppColors.textSecondary),
              prefixIcon: const Icon(Icons.school_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.divider.withValues(alpha: 0.3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.divider.withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: AppColors.primary),
              ),
              filled: true,
              fillColor: AppColors.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            items: _classYearOptions.map((String classYear) {
              return DropdownMenuItem<String>(
                value: classYear,
                child: Text(
                  classYear,
                  style: TextStyle(color: AppColors.textPrimary),
                ),
              );
            }).toList(),
            onChanged: (String? value) {
              setState(() {
                _selectedClassYear = value;
              });
            },
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please select your class year';
              }
              return null;
            },
            dropdownColor: AppColors.surface,
            icon: Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }


  Future<void> _completeProfile() async {
    if (!_formKey.currentState!.validate()) return;

    if (_interests.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one interest'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    if (_selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your gender identity'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      await authProvider.updateProfile(
        displayName: _fullNameController.text.trim(),
        photoUrl: null,
        bio: _aboutController.text.trim().isNotEmpty ? _aboutController.text.trim() : null,
        classYear: _selectedClassYear,
        location: _locationController.text.trim(),
        interests: _interests,
        gender: _selectedGender!,
      );

      if (mounted) {
        // Navigate directly to main app - onboarding complete
        context.go('/main');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update profile: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Privacy Notice
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.visibility,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'This information will be publicly visible to other users',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Full Name Field
                CustomTextField(
                  label: 'Full Name',
                  hint: 'Enter your full name',
                  controller: _fullNameController,
                  keyboardType: TextInputType.name,
                  textInputAction: TextInputAction.next,
                  prefixIcon: const Icon(Icons.person_outlined),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your full name';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // Class Year Field
                _buildClassYearSection(),

                const SizedBox(height: 16),

                // Location Field
                CustomTextField(
                  label: 'Location',
                  hint: 'Enter your dorm',
                  controller: _locationController,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.next,
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter your location';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                // About Section
                CustomTextField(
                  label: 'About Me',
                  hint: 'Tell us about yourself (optional)',
                  controller: _aboutController,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  maxLines: 3,
                  prefixIcon: const Icon(Icons.info_outlined),
                  validator: null, // Optional field
                ),

                const SizedBox(height: 24),

                // Interests Section
                Text(
                  'Interests',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 8),

                // Add Interest Field
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        label: 'Add Interest',
                        hint: 'Type an interest',
                        controller: _interestController,
                        textInputAction: TextInputAction.done,
                        onChanged: (value) {
                          if (value.endsWith('\n')) {
                            _addInterest(value.trim());
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () =>
                          _addInterest(_interestController.text.trim()),
                      icon: const Icon(Icons.add),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Popular Interests
                if (_interests.length < 10) ...[
                  Text(
                    'Popular Interests',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _popularInterests
                        .where((interest) => !_interests.contains(interest))
                        .map(
                          (interest) => FilterChip(
                            label: Text(interest),
                            onSelected: (selected) {
                              if (selected) _addInterest(interest);
                            },
                            backgroundColor: AppColors.surface,
                            selectedColor: AppColors.primary.withOpacity(0.2),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // Selected Interests
                if (_interests.isNotEmpty) ...[
                  Text(
                    'Your Interests (${_interests.length})',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _interests
                        .map(
                          (interest) => Chip(
                            label: Text(interest),
                            onDeleted: () => _removeInterest(interest),
                            backgroundColor: AppColors.primary.withOpacity(0.1),
                            deleteIconColor: AppColors.primary,
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 24),
                ],

                // Gender Identity Section
                Text(
                  'Gender Identity',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),

                // Privacy notice for gender
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.divider.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.security,
                        color: AppColors.textSecondary,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This information is collected for user safety and will not be shown to other users',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Gender selection options
                Column(
                  children: _genderOptions.map((option) {
                    final isSelected = _selectedGender == option['value'];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedGender = option['value'];
                          });
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withOpacity(0.1)
                                : AppColors.surface,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.divider.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: isSelected
                                      ? AppColors.primary
                                      : Colors.transparent,
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.primary
                                        : AppColors.divider,
                                    width: 2,
                                  ),
                                ),
                                child: isSelected
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                        size: 14,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                option['label']!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.textPrimary,
                                      fontWeight: isSelected
                                          ? FontWeight.w500
                                          : FontWeight.normal,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 32),

                // Complete Profile Button
                CustomButton(
                  text: 'Complete Profile',
                  onPressed: _completeProfile,
                  isLoading: _isLoading,
                  width: double.infinity,
                  height: 52,
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
