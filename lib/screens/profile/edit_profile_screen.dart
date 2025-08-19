import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../utils/colors.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

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
  late final TextEditingController _ageController;
  final TextEditingController _interestController = TextEditingController();

  // State
  Set<String> _selectedInterests = {};
  bool _isLoading = false;
  String? _error;

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

  @override
  void initState() {
    super.initState();
    _initializeControllers();
  }

  void _initializeControllers() {
    _displayNameController = TextEditingController(text: widget.user.displayName ?? '');
    _bioController = TextEditingController(text: widget.user.bio ?? '');
    _locationController = TextEditingController(text: widget.user.location ?? '');
    _ageController = TextEditingController(text: widget.user.age?.toString() ?? '');
    _selectedInterests = Set<String>.from(widget.user.interests);
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _ageController.dispose();
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
              _buildSectionTitle('Location (optional)'),
              const SizedBox(height: 6),
              CustomTextField(
                controller: _locationController,
                hint: 'Enter your dorm',
              ),

              const SizedBox(height: 16),

              // Age
              _buildSectionTitle('Age (optional)'),
              const SizedBox(height: 6),
              CustomTextField(
                controller: _ageController,
                hint: 'Enter your age',
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final age = int.tryParse(value);
                    if (age == null) {
                      return 'Please enter a valid age';
                    }
                    if (age < 13 || age > 120) {
                      return 'Age must be between 13 and 120';
                    }
                  }
                  return null;
                },
              ),

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

      // Parse age
      int? age;
      if (_ageController.text.isNotEmpty) {
        age = int.tryParse(_ageController.text);
      }

      // Update profile using AuthProvider
      await authProvider.updateProfile(
        displayName: _displayNameController.text.trim().isEmpty 
            ? null 
            : _displayNameController.text.trim(),
        bio: _bioController.text.trim().isEmpty 
            ? null 
            : _bioController.text.trim(),
        location: _locationController.text.trim().isEmpty 
            ? null 
            : _locationController.text.trim(),
        age: age,
        interests: _selectedInterests.toList(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.of(context).pop(); // Go back to profile screen
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