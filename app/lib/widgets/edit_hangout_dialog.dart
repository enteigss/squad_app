import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/post_model.dart';
import '../utils/colors.dart';
import '../constants/bu_locations.dart';

class EditHangoutDialog extends StatefulWidget {
  final Post post;
  final Function(String description, DateTime? scheduledTime, String? location)
  onSave;

  const EditHangoutDialog({
    super.key,
    required this.post,
    required this.onSave,
  });

  @override
  State<EditHangoutDialog> createState() => _EditHangoutDialogState();

  static Future<void> show(
    BuildContext context, {
    required Post post,
    required Function(
      String description,
      DateTime? scheduledTime,
      String? location,
    )
    onSave,
  }) {
    return showDialog(
      context: context,
      builder: (context) => EditHangoutDialog(post: post, onSave: onSave),
    );
  }
}

class _EditHangoutDialogState extends State<EditHangoutDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _descriptionController;
  late TextEditingController _customLocationController;
  late DateTime? _selectedDateTime;
  String? _selectedLocation;
  String? _customLocation;
  bool _showLocationSearch = false;
  List<String> _filteredLocations = [];

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(
      text: widget.post.description,
    );
    _customLocationController = TextEditingController();
    _selectedDateTime = widget.post.scheduledTime;
    _selectedLocation = widget.post.location;
    _filteredLocations = BULocations.allLocations;

    // Check if the current location is a custom one
    if (_selectedLocation != null &&
        !BULocations.allLocations.contains(_selectedLocation) &&
        _selectedLocation!.isNotEmpty) {
      _customLocation = _selectedLocation;
      _selectedLocation = BULocations.otherOption;
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _customLocationController.dispose();
    super.dispose();
  }

  void _filterLocations(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredLocations = BULocations.allLocations;
      } else {
        _filteredLocations = BULocations.allLocations
            .where(
              (location) =>
                  location.toLowerCase().contains(query.toLowerCase()),
            )
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
          backgroundColor: AppColors.background,
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
                  hintText: 'e.g., My apartment, A coffee shop...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                autofocus: true,
                textCapitalization: TextCapitalization.words,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(
                  context,
                ).pop(_customLocationController.text.trim());
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

    if (result != null && result.isNotEmpty) {
      setState(() {
        _customLocation = result;
      });
    } else if (result == null) {
      // User cancelled, revert to previous selection
      setState(() {
        _selectedLocation = null;
      });
    }
  }

  Future<void> _selectDateTime() async {
    final currentTime = _selectedDateTime ?? DateTime.now();

    // Show date picker
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: currentTime.isAfter(DateTime.now())
          ? currentTime
          : DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedDate == null || !mounted) return;

    // Show time picker
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(currentTime),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (selectedTime == null || !mounted) return;

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

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'Select date & time';
    final formatter = DateFormat('MMM d, y \'at\' h:mm a');
    return formatter.format(dateTime);
  }

  void _handleSave() {
    if (_formKey.currentState!.validate()) {
      final description = _descriptionController.text.trim();

      // Get final location value
      String? finalLocation;
      if (_selectedLocation != null) {
        if (BULocations.isOtherOption(_selectedLocation!)) {
          finalLocation = _customLocation?.trim();
        } else {
          finalLocation = _selectedLocation;
        }
      }

      widget.onSave(description, _selectedDateTime, finalLocation);
      Navigator.of(context).pop();
    }
  }

  Widget _buildLocationSelector() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.textSecondary.withValues(alpha: 0.3),
        ),
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
                  Icon(Icons.location_on, color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      BULocations.getDisplayText(
                        _selectedLocation,
                        _customLocation,
                      ),
                      style: TextStyle(
                        fontSize: 14,
                        color: _selectedLocation == null
                            ? AppColors.textSecondary.withValues(alpha: 0.7)
                            : AppColors.textPrimary,
                      ),
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
                            size: 18,
                          ),
                        ),
                      const SizedBox(width: 8),
                      Icon(
                        _showLocationSearch
                            ? Icons.expand_less
                            : Icons.expand_more,
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
      constraints: const BoxConstraints(maxHeight: 300),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Search field
          TextField(
            decoration: InputDecoration(
              hintText: 'Search locations...',
              prefixIcon: const Icon(Icons.search, size: 20),
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

          // Location list
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Other option first
                  if (_filteredLocations.contains(BULocations.otherOption))
                    _buildLocationCategory('Custom', [BULocations.otherOption]),

                  // Location categories
                  ...BULocations.locationsByCategory.entries.map((category) {
                    final categoryLocations = _filteredLocations
                        .where((location) => category.value.contains(location))
                        .toList();

                    if (categoryLocations.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    return _buildLocationCategory(
                      category.key,
                      categoryLocations,
                    );
                  }),
                ],
              ),
            ),
          ),
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
            fontSize: 13,
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
                style: TextStyle(color: AppColors.textPrimary, fontSize: 14),
              ),
            ),
          );
        }),
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.background,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Edit Hangout',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Description Field
                      Text(
                        'Description (optional)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Add more details...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: AppColors.surface,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Date & Time Picker
                      Text(
                        'Date & Time',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: _selectDateTime,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: AppColors.textSecondary.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 20,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                _formatDateTime(_selectedDateTime),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: _selectedDateTime == null
                                      ? AppColors.textSecondary
                                      : AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Location Selector
                      Text(
                        'Location (optional)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildLocationSelector(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _handleSave,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
