import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../../utils/colors.dart';

class AvailabilityScreen extends StatefulWidget {
  const AvailabilityScreen({super.key});

  @override
  State<AvailabilityScreen> createState() => _AvailabilityScreenState();
}

class _AvailabilityScreenState extends State<AvailabilityScreen> {
  bool _isLoading = false;

  // Availability data structure: day -> time slots
  Map<String, Map<String, bool>> _availability = {
    'monday': {'morning': false, 'afternoon': false, 'evening': false},
    'tuesday': {'morning': false, 'afternoon': false, 'evening': false},
    'wednesday': {'morning': false, 'afternoon': false, 'evening': false},
    'thursday': {'morning': false, 'afternoon': false, 'evening': false},
    'friday': {'morning': false, 'afternoon': false, 'evening': false},
    'saturday': {'morning': false, 'afternoon': false, 'evening': false},
    'sunday': {'morning': false, 'afternoon': false, 'evening': false},
  };

  final List<String> _days = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  final Map<String, String> _dayLabels = {
    'monday': 'Monday',
    'tuesday': 'Tuesday',
    'wednesday': 'Wednesday',
    'thursday': 'Thursday',
    'friday': 'Friday',
    'saturday': 'Saturday',
    'sunday': 'Sunday',
  };

  final List<String> _timeSlots = ['morning', 'afternoon', 'evening'];

  final Map<String, String> _timeSlotLabels = {
    'morning': 'Morning',
    'afternoon': 'Afternoon',
    'evening': 'Evening',
  };

  void _toggleAvailability(String day, String timeSlot) {
    setState(() {
      _availability[day]![timeSlot] = !_availability[day]![timeSlot]!;
    });
  }

  bool _hasSelectedAvailability() {
    for (final day in _availability.values) {
      for (final isAvailable in day.values) {
        if (isAvailable) return true;
      }
    }
    return false;
  }

  Future<void> _completeAvailability() async {
    if (!_hasSelectedAvailability()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one availability slot'),
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

      await authProvider.updateAvailability(_availability);

      if (mounted) {
        // Navigate to home screen using GoRouter
        context.go('/home');

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile setup complete!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save availability: ${e.toString()}'),
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
        title: const Text('When Are You Available?'),
        backgroundColor: AppColors.background,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Select your availability',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose the days and times when you\'re available to hang out',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Days and time slots
                    ..._days.map((day) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.divider.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _dayLabels[day]!,
                              style: Theme.of(context).textTheme.bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: _timeSlots.map((timeSlot) {
                                final isSelected =
                                    _availability[day]![timeSlot]!;
                                return Expanded(
                                  child: GestureDetector(
                                    onTap: () =>
                                        _toggleAvailability(day, timeSlot),
                                    child: Container(
                                      margin: EdgeInsets.only(
                                        right: timeSlot != _timeSlots.last
                                            ? 8
                                            : 0,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                        horizontal: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.primary
                                            : AppColors.background,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isSelected
                                              ? AppColors.primary
                                              : AppColors.divider.withOpacity(
                                                  0.3,
                                                ),
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          _timeSlotLabels[timeSlot]!,
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(
                                                color: isSelected
                                                    ? Colors.white
                                                    : AppColors.textSecondary,
                                                fontWeight: isSelected
                                                    ? FontWeight.w500
                                                    : FontWeight.normal,
                                              ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      );
                    }).toList(),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Complete Setup Button - Fixed at bottom
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: CustomButton(
                text: 'Complete Setup',
                onPressed: _completeAvailability,
                isLoading: _isLoading,
                width: double.infinity,
                height: 52,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
