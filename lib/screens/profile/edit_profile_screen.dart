import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../utils/colors.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../../constants/bu_dorms.dart';

class EditProfileScreen extends StatefulWidget {
  final UserModel user;

  const EditProfileScreen({
    super.key,
    required this.user,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirestoreService _firestoreService = FirestoreService();

  // Controllers
  late final TextEditingController _displayNameController;
  late final TextEditingController _bioController;
  late final TextEditingController _locationController;
  String? _selectedClassYear;
  final TextEditingController _interestController = TextEditingController();

  // State
  Set<String> _selectedInterests = {};
  String? _selectedGender;
  bool _isLoading = false;
  String? _error;
  String? _selectedLocation;
  bool _showCustomLocationField = false;

  // Class year options
  final List<String> _classYearOptions = [
    'Freshman',
    'Sophomore', 
    'Junior',
    'Senior',
    'Graduate',
  ];

  // Available interests
  final List<String> _availableInterests = [
    'Sports',
    'Music',
    'Movies',
    'Reading',
    'Cooking',
    'Travel',
    'Photography',
    'Gaming',
    'Art',
    'Fitness',
    'Technology',
    'Food',
    'Nature',
    'Dancing',
    'Writing',
    'Fashion',
    'Comedy',
    'Learning',
    'Volunteering',
    'Networking',
  ];

  // Gender options
  final List<Map<String, String>> _genderOptions = [
    {'value': 'woman', 'label': 'Woman'},
    {'value': 'man', 'label': 'Man'},
    {'value': 'non_binary', 'label': 'Non-binary'},
    {'value': 'prefer_not_to_say', 'label': 'Prefer not to say'},
  ];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _displayNameController = TextEditingController(text: widget.user.displayName ?? '');
    _bioController = TextEditingController(text: widget.user.bio ?? '');
    _locationController = TextEditingController();
    _selectedClassYear = widget.user.classYear;
    _selectedInterests = Set<String>.from(widget.user.interests);
    _selectedGender = widget.user.gender;

    // Initialize location dropdown
    final userLocation = widget.user.location ?? '';
    if (userLocation.isNotEmpty && BUDorms.dormitories.contains(userLocation)) {
      _selectedLocation = userLocation;
      _showCustomLocationField = false;
    } else if (userLocation.isNotEmpty) {
      _selectedLocation = 'Other';
      _showCustomLocationField = true;
      _locationController.text = userLocation;
    } else {
      _selectedLocation = null;
      _showCustomLocationField = false;
    }
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    // No need to dispose _selectedClassYear as it's not a controller
    _interestController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Profile Picture Section
              _buildProfilePictureSection(),
              
              const SizedBox(height: 20),
              
              // Display Name
              _buildSectionTitle('Display Name'),
              const SizedBox(height: 6),
              CustomTextField(
                controller: _displayNameController,
                hint: 'Enter your display name',
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Display name is required';
                  }
                  if (value.length < 2) {
                    return 'Display name must be at least 2 characters';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Bio
              _buildSectionTitle('Bio (optional)'),
              const SizedBox(height: 6),
              CustomTextField(
                controller: _bioController,
                hint: 'Tell us about yourself...',
                maxLines: 4,
                validator: (value) {
                  if (value != null && value.length > 500) {
                    return 'Bio must be less than 500 characters';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // Location
              _buildLocationSection(),

              const SizedBox(height: 16),

              // Class Year
              _buildSectionTitle('Class Year (optional)'),
              const SizedBox(height: 6),
              _buildClassYearDropdown(),

              const SizedBox(height: 16),

              // Gender
              _buildSectionTitle('Gender'),
              const SizedBox(height: 6),
              _buildGenderSelector(),

              const SizedBox(height: 16),

              // Interests
              _buildSectionTitle('Interests (optional)'),
              const SizedBox(height: 6),
              _buildInterestsSelector(),

              const SizedBox(height: 20),

              // Error message
              if (_error != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: AppColors.error, fontSize: 14),
                  ),
                ),

              // Save Button
              CustomButton(
                text: _isLoading ? 'Saving...' : 'Save Changes',
                onPressed: _isLoading ? null : _saveProfile,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePictureSection() {
    return Column(
      children: [
        // Profile Picture
        CircleAvatar(
          radius: 40,
          backgroundColor: AppColors.primary.withValues(alpha: 0.1),
          backgroundImage: widget.user.photoUrl != null 
            ? NetworkImage(widget.user.photoUrl!) 
            : null,
          child: widget.user.photoUrl == null
            ? Icon(
                Icons.person,
                size: 40,
                color: AppColors.primary,
              )
            : null,
        ),
        
        const SizedBox(height: 12),
        
        // Change Photo Button (placeholder for now)
        TextButton.icon(
          onPressed: _changeProfilePhoto,
          icon: const Icon(Icons.camera_alt),
          label: const Text('Change Photo'),
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
          ),
        ),
      ],
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

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('Location (optional)'),
        const SizedBox(height: 6),
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
            value: _selectedLocation,
            decoration: InputDecoration(
              hintText: 'Select your dorm',
              hintStyle: TextStyle(color: AppColors.textSecondary),
              prefixIcon: const Icon(Icons.location_on_outlined),
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
            items: BUDorms.dormitories.map((String dorm) {
              return DropdownMenuItem<String>(
                value: dorm,
                child: Text(
                  dorm,
                  style: TextStyle(color: AppColors.textPrimary),
                ),
              );
            }).toList(),
            onChanged: (String? value) {
              setState(() {
                _selectedLocation = value;
                _showCustomLocationField = value == 'Other';
                if (value != 'Other') {
                  _locationController.clear();
                }
              });
            },
            dropdownColor: AppColors.surface,
            icon: Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
          ),
        ),
        if (_showCustomLocationField) ...[
          const SizedBox(height: 12),
          CustomTextField(
            controller: _locationController,
            hint: 'Enter your custom location',
            prefixIcon: const Icon(Icons.edit_location_outlined),
          ),
        ],
      ],
    );
  }

  Widget _buildClassYearDropdown() {
    return Container(
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
        dropdownColor: AppColors.surface,
        icon: Icon(Icons.arrow_drop_down, color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildGenderSelector() {
    return Container(
      padding: const EdgeInsets.all(12),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Privacy notice
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Gender helps us match you with the right hangouts. This information is not visible to other users.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Gender options
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
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected 
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected 
                            ? AppColors.primary 
                            : AppColors.divider.withValues(alpha: 0.3),
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          color: isSelected ? AppColors.primary : AppColors.textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            option['label']!,
                            style: TextStyle(
                              color: isSelected ? AppColors.primary : AppColors.textPrimary,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildInterestsSelector() {
    return Container(
      padding: const EdgeInsets.all(12),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add Custom Interest Field
          Row(
            children: [
              Expanded(
                child: CustomTextField(
                  controller: _interestController,
                  hint: 'Add custom interest',
                  textInputAction: TextInputAction.done,
                  onChanged: (value) {
                    if (value.endsWith('\n')) {
                      _addCustomInterest(value.trim());
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _addCustomInterest(_interestController.text.trim()),
                icon: const Icon(Icons.add),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Selected Interests (if any)
          if (_selectedInterests.isNotEmpty) ...[
            Text(
              'Your Interests (${_selectedInterests.length})',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _selectedInterests.map((interest) {
                return Chip(
                  label: Text(interest),
                  onDeleted: () => _removeInterest(interest),
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  deleteIconColor: AppColors.primary,
                  labelStyle: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
          
          // Available Interests
          Text(
            'Popular Interests (tap to add):',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _availableInterests
                .where((interest) => !_selectedInterests.contains(interest))
                .map((interest) {
              return GestureDetector(
                onTap: () => _toggleInterest(interest),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    interest,
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
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

  void _toggleInterest(String interest) {
    setState(() {
      if (_selectedInterests.contains(interest)) {
        _selectedInterests.remove(interest);
      } else {
        _selectedInterests.add(interest);
      }
    });
  }

  void _addCustomInterest(String interest) {
    if (interest.isNotEmpty && !_selectedInterests.contains(interest)) {
      setState(() {
        _selectedInterests.add(interest);
        _interestController.clear();
      });
    }
  }

  void _removeInterest(String interest) {
    setState(() {
      _selectedInterests.remove(interest);
    });
  }

  void _changeProfilePhoto() {
    // Placeholder for photo change functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Photo upload functionality coming soon!'),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser;
      
      if (currentUser == null) {
        throw Exception('User not found');
      }

      // Class year is already set in _selectedClassYear

      // Update profile using AuthProvider
      await authProvider.updateProfile(
        displayName: _displayNameController.text.trim().isEmpty 
            ? null 
            : _displayNameController.text.trim(),
        bio: _bioController.text.trim().isEmpty 
            ? null 
            : _bioController.text.trim(),
        location: _selectedLocation == null
            ? null
            : _selectedLocation == 'Other'
                ? (_locationController.text.trim().isEmpty ? null : _locationController.text.trim())
                : _selectedLocation,
        classYear: _selectedClassYear,
        interests: _selectedInterests.toList(),
        gender: _selectedGender,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).pop(); // Go back to profile screen
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to update profile: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}