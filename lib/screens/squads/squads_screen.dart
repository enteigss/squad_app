import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../providers/auth_provider.dart' as app_auth;
import '../../providers/user_preferences_provider.dart';
import '../../utils/colors.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class SquadsScreen extends StatefulWidget {
  const SquadsScreen({super.key});

  @override
  State<SquadsScreen> createState() => _SquadsScreenState();
}

class _SquadsScreenState extends State<SquadsScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _currentPartyPackMember;
  bool _isMutualPartyPack = false;
  List<String> _incomingDesignations = [];
  String? _error;
  bool? _localSquadsOptIn; // Local override for immediate UI updates

  @override
  void initState() {
    super.initState();
    _loadCurrentPartyPackMember();
    _initializePreferences();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _initializePreferences() {
    final authProvider = Provider.of<app_auth.AuthProvider>(
      context,
      listen: false,
    );
    final preferencesProvider = Provider.of<UserPreferencesProvider>(
      context,
      listen: false,
    );

    final user = authProvider.currentUser;
    if (user != null) {
      preferencesProvider.initialize(user.squadsOptIn);
    }
  }

  Future<void> _handleSquadsOptInToggle(bool? value) async {
    if (value == null) return;

    // Update local state immediately for responsive UI
    setState(() {
      _localSquadsOptIn = value;
    });

    try {
      // Update through preferences provider instead of auth provider
      final preferencesProvider = Provider.of<UserPreferencesProvider>(
        context,
        listen: false,
      );

      await preferencesProvider.updateSquadsOptIn(value);

      // Clear local override since preferences provider has the updated state
      setState(() {
        _localSquadsOptIn = null;
      });
    } catch (e) {
      // Revert local state on error
      setState(() {
        _localSquadsOptIn = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to update squads participation: ${e.toString()}',
            ),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _loadCurrentPartyPackMember() async {
    final authProvider = Provider.of<app_auth.AuthProvider>(
      context,
      listen: false,
    );
    final user = authProvider.currentUser;

    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.id)
            .get();

        if (doc.exists && mounted) {
          final data = doc.data()!;
          final designatedEmail = data['partyPackMemberEmail'];
          final incoming = List<String>.from(
            data['incomingPartyPackRequests'] ?? [],
          );

          setState(() {
            _currentPartyPackMember = designatedEmail;
            _incomingDesignations = incoming;
          });

          // Check if the designation is mutual
          if (designatedEmail != null) {
            await _checkMutualDesignation(user.email, designatedEmail);
          } else {
            setState(() {
              _isMutualPartyPack = false;
            });
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _error = 'Failed to load party pack member: ${e.toString()}';
          });
        }
      }
    }
  }

  Future<void> _checkMutualDesignation(
    String currentUserEmail,
    String designatedEmail,
  ) async {
    try {
      // Find the user with the designated email
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: designatedEmail)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty && mounted) {
        final designatedUserDoc = querySnapshot.docs.first;
        final designatedUserData = designatedUserDoc.data();
        final theirDesignatedEmail = designatedUserData['partyPackMemberEmail'];

        // Check if they designated us back
        final isMutual = theirDesignatedEmail == currentUserEmail;

        setState(() {
          _isMutualPartyPack = isMutual;
        });
      } else {
        setState(() {
          _isMutualPartyPack = false;
        });
      }
    } catch (e) {
      setState(() {
        _isMutualPartyPack = false;
      });
    }
  }

  Future<void> _updateIncomingDesignations({
    required String targetUserEmail,
    required String designatingUserEmail,
    required bool isAdding,
  }) async {
    try {
      // Find the target user by email
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: targetUserEmail)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final targetUserDoc = querySnapshot.docs.first;

        if (isAdding) {
          // Add to their incoming designations
          await targetUserDoc.reference.update({
            'incomingPartyPackRequests': FieldValue.arrayUnion([
              designatingUserEmail,
            ]),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          // Remove from their incoming designations
          await targetUserDoc.reference.update({
            'incomingPartyPackRequests': FieldValue.arrayRemove([
              designatingUserEmail,
            ]),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      print('Error updating incoming designations: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Squads'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showSquadsInfo,
            tooltip: 'How does squads work?',
          ),
        ],
      ),
      body: Consumer2<app_auth.AuthProvider, UserPreferencesProvider>(
        builder: (context, authProvider, preferencesProvider, child) {
          final user = authProvider.currentUser;
          if (user == null) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          final isInSquad = user.groupId != null && user.groupId!.isNotEmpty;

          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Squads Opt-In Section
                  _buildSquadsOptInSection(user, preferencesProvider),

                  const SizedBox(height: 12),

                  // Only show squad features if user has opted in
                  if ((_localSquadsOptIn ?? 
                      (preferencesProvider.squadsOptIn ?? user.squadsOptIn ?? false)) ==
                      true) ...[
                    // Squad Status Section
                    _buildSquadStatusSection(isInSquad, user.groupId),

                    const SizedBox(height: 12),

                    // Current Party Pack Member Status
                    _buildCurrentPartyPackSection(),

                    const SizedBox(height: 12),

                    // Designate Party Pack Member Section
                    _buildDesignatePartyPackSection(),

                    if (_incomingDesignations.isNotEmpty) ...[
                      const SizedBox(height: 12),

                      // Incoming Party Pack Requests Section
                      _buildIncomingRequestsSection(),
                    ],
                  ] else ...[
                    // Show message when not opted in
                    _buildOptOutMessage(),
                  ],

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: AppColors.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        _error!,
                        style: TextStyle(color: AppColors.error, fontSize: 14),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOptOutMessage() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.group_off,
            size: 64,
            color: AppColors.textSecondary.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Squad Features Disabled',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enable squad participation above to access squad matching, party pack features, and group formation.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSquadsOptInSection(dynamic user, UserPreferencesProvider preferencesProvider) {
    final isOptedIn = _localSquadsOptIn ?? 
        (preferencesProvider.squadsOptIn ?? user.squadsOptIn ?? false);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.toggle_on, color: AppColors.primary, size: 24),
              const SizedBox(width: 10),
              Text(
                'Squads Participation',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Enable squad matching to be automatically grouped with compatible users based on your preferences.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    color: isOptedIn
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.textSecondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isOptedIn
                          ? AppColors.success.withValues(alpha: 0.3)
                          : AppColors.textSecondary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isOptedIn ? Icons.check_circle : Icons.cancel,
                        color: isOptedIn
                            ? AppColors.success
                            : AppColors.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isOptedIn ? 'Opted In' : 'Not Participating',
                        style: TextStyle(
                          color: isOptedIn
                              ? AppColors.success
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Switch(
                value: isOptedIn,
                onChanged: _isLoading
                    ? null
                    : (bool? value) {
                        if (value != null) {
                          _handleSquadsOptInToggle(value);
                        }
                      },
                activeColor: AppColors.primary,
                activeTrackColor: AppColors.primary.withValues(alpha: 0.3),
                inactiveThumbColor: AppColors.textSecondary,
                inactiveTrackColor: AppColors.textSecondary.withValues(
                  alpha: 0.3,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSquadStatusSection(bool isInSquad, String? groupId) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.group, color: AppColors.primary, size: 24),
              const SizedBox(width: 10),
              Text(
                'Squad Status',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: isInSquad
                  ? AppColors.success.withValues(alpha: 0.1)
                  : AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isInSquad
                    ? AppColors.success.withValues(alpha: 0.3)
                    : AppColors.error.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isInSquad ? Icons.check_circle : Icons.cancel,
                  color: isInSquad ? AppColors.success : AppColors.error,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isInSquad ? 'You\'re in a Squad!' : 'Not in a Squad',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isInSquad ? AppColors.success : AppColors.error,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (isInSquad && groupId != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Squad ID: ${groupId.substring(0, 8)}...',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: CustomButton(
                          text: 'View Squad',
                          onPressed: () => context.push('/group'),
                          height: 36,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: CustomButton(
                          text: 'Chat',
                          onPressed: () => context.push('/chat'),
                          height: 36,
                          backgroundColor: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPartyPackSection() {
    final hasPartyPackMember =
        _currentPartyPackMember != null && _currentPartyPackMember!.isNotEmpty;

    // Determine status and colors based on mutual designation
    Color statusColor;
    Color backgroundColor;
    Color borderColor;
    IconData statusIcon;
    String statusTitle;
    String statusDescription;

    if (!hasPartyPackMember) {
      statusColor = AppColors.textSecondary;
      backgroundColor = AppColors.textSecondary.withValues(alpha: 0.1);
      borderColor = AppColors.textSecondary.withValues(alpha: 0.3);
      statusIcon = Icons.person_add_disabled;
      statusTitle = 'No Party Pack Member';
      statusDescription = '';
    } else if (_isMutualPartyPack) {
      statusColor = AppColors.success;
      backgroundColor = AppColors.success.withValues(alpha: 0.1);
      borderColor = AppColors.success.withValues(alpha: 0.3);
      statusIcon = Icons.group;
      statusTitle = 'Party Pack Confirmed! 🎉';
      statusDescription =
          'You and ${_currentPartyPackMember!} are now party pack partners';
    } else {
      statusColor = AppColors.primary;
      backgroundColor = AppColors.primary.withValues(alpha: 0.1);
      borderColor = AppColors.primary.withValues(alpha: 0.3);
      statusIcon = Icons.hourglass_empty;
      statusTitle = 'Waiting for Response';
      statusDescription =
          'Waiting for ${_currentPartyPackMember!} to select you back to form a party pack';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.people_alt, color: AppColors.primary, size: 24),
              const SizedBox(width: 10),
              Text(
                'Party Pack Status',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: borderColor, width: 1),
            ),
            child: Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        statusTitle,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: statusColor,
                          fontSize: 14,
                        ),
                      ),
                      if (hasPartyPackMember) ...[
                        if (!_isMutualPartyPack) ...[
                          const SizedBox(height: 2),
                          Text(
                            _currentPartyPackMember!,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const SizedBox(height: 2),
                        Text(
                          statusDescription,
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (hasPartyPackMember) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: _removePartyPackMember,
                    icon: Icon(Icons.remove_circle_outline, size: 16),
                    label: Text(_isMutualPartyPack ? 'Leave' : 'Cancel'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                      textStyle: TextStyle(fontSize: 12),
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesignatePartyPackSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Designate Party Pack Member',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Enter email to party pack with:',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
          ),
          const SizedBox(height: 8),
          CustomTextField(
            controller: _emailController,
            hint: 'Enter email address',
            keyboardType: TextInputType.emailAddress,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            hintStyle: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter an email address';
              }
              if (!RegExp(
                r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
              ).hasMatch(value.trim())) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 8),
          CustomButton(
            text: _isLoading ? 'Saving...' : 'Set Party Pack Member',
            onPressed: _isLoading ? null : _setPartyPackMember,
            width: double.infinity,
            isLoading: _isLoading,
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingRequestsSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.notifications_active,
                color: AppColors.primary,
                size: 24,
              ),
              const SizedBox(width: 10),
              Text(
                'Incoming Party Pack Requests',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'These people want to party pack with you:',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 12),
          ..._incomingDesignations
              .map((email) => _buildIncomingRequestCard(email))
              .toList(),
        ],
      ),
    );
  }

  Widget _buildIncomingRequestCard(String email) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.person, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      email,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Wants to be your party pack partner',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Accept button
              Expanded(
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: TextButton.icon(
                    onPressed: () => _acceptPartyPackRequest(email),
                    icon: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    ),
                    label: const Text(
                      'Accept',
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Decline button
              Expanded(
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: TextButton.icon(
                    onPressed: () => _declinePartyPackRequest(email),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 16,
                    ),
                    label: const Text(
                      'Decline',
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _acceptPartyPackRequest(String requesterEmail) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<app_auth.AuthProvider>(
        context,
        listen: false,
      );
      final user = authProvider.currentUser;

      if (user != null && user.email != null) {
        // Remove old designation if exists
        if (_currentPartyPackMember != null) {
          await _updateIncomingDesignations(
            targetUserEmail: _currentPartyPackMember!,
            designatingUserEmail: user.email!,
            isAdding: false,
          );
        }

        // Set the requester as our party pack member
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.id)
            .update({
              'partyPackMemberEmail': requesterEmail,
              'updatedAt': FieldValue.serverTimestamp(),
            });

        // Add ourselves to requester's incoming designations
        await _updateIncomingDesignations(
          targetUserEmail: requesterEmail,
          designatingUserEmail: user.email!,
          isAdding: true,
        );

        // Remove requester from our incoming list
        setState(() {
          _incomingDesignations.remove(requesterEmail);
          _currentPartyPackMember = requesterEmail;
          _isMutualPartyPack = true; // Since they designated us and we accepted
        });

        // Update our incoming list in Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.id)
            .update({'incomingPartyPackRequests': _incomingDesignations});

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Party pack confirmed with $requesterEmail! 🎉'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to accept party pack request: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _declinePartyPackRequest(String requesterEmail) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<app_auth.AuthProvider>(
        context,
        listen: false,
      );
      final user = authProvider.currentUser;

      if (user != null && user.email != null) {
        // Remove requester from our incoming list
        setState(() {
          _incomingDesignations.remove(requesterEmail);
        });

        // Update our incoming list in Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.id)
            .update({'incomingPartyPackRequests': _incomingDesignations});

        // Remove our email from requester's party pack member field if they designated us
        final requesterQuery = await FirebaseFirestore.instance
            .collection('users')
            .where('email', isEqualTo: requesterEmail)
            .limit(1)
            .get();

        if (requesterQuery.docs.isNotEmpty) {
          final requesterDoc = requesterQuery.docs.first;
          final requesterData = requesterDoc.data();

          if (requesterData['partyPackMemberEmail'] == user.email) {
            await requesterDoc.reference.update({
              'partyPackMemberEmail': FieldValue.delete(),
            });
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Party pack request from $requesterEmail declined'),
              backgroundColor: AppColors.textSecondary,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to decline party pack request: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _setPartyPackMember() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<app_auth.AuthProvider>(
        context,
        listen: false,
      );
      final user = authProvider.currentUser;

      if (user != null) {
        final newMemberEmail = _emailController.text.trim();
        final currentUserEmail = user.email;

        // Check if the email is already registered
        final isRegistered = await _checkIfEmailRegistered(newMemberEmail);

        // Remove old designation from previous member's incoming list
        if (_currentPartyPackMember != null && currentUserEmail != null) {
          await _updateIncomingDesignations(
            targetUserEmail: _currentPartyPackMember!,
            designatingUserEmail: currentUserEmail,
            isAdding: false,
          );
        }

        // Update current user's designation
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.id)
            .update({
              'partyPackMemberEmail': newMemberEmail,
              'updatedAt': FieldValue.serverTimestamp(),
            });

        if (isRegistered) {
          // User is registered - use existing logic
          if (currentUserEmail != null) {
            await _updateIncomingDesignations(
              targetUserEmail: newMemberEmail,
              designatingUserEmail: currentUserEmail,
              isAdding: true,
            );
          }

          // Check for mutual designation
          if (currentUserEmail != null) {
            await _checkMutualDesignation(currentUserEmail, newMemberEmail);
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Party pack member set to $newMemberEmail'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        } else {
          // User is not registered - create invitation
          await _createPartyPackInvitation(
            newMemberEmail,
            currentUserEmail,
            user.displayName,
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Invitation sent to $newMemberEmail! They\'ll see your party pack request when they join Squad.',
                ),
                backgroundColor: AppColors.primary,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }

        setState(() {
          _currentPartyPackMember = newMemberEmail;
          _emailController.clear();
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to set party pack member: ${e.toString()}';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to set party pack member: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<bool> _checkIfEmailRegistered(String email) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking if email is registered: $e');
      return false;
    }
  }

  Future<void> _createPartyPackInvitation(
    String inviteeEmail,
    String? inviterEmail,
    String? inviterName,
  ) async {
    try {
      if (inviterEmail == null) return;

      // Create invitation document
      await FirebaseFirestore.instance.collection('party_invitations').add({
        'inviteeEmail': inviteeEmail,
        'inviterEmail': inviterEmail,
        'inviterName': inviterName,
        'createdAt': FieldValue.serverTimestamp(),
        'emailSent': false,
        'processed': false,
      });

      print('Party pack invitation created for $inviteeEmail');
    } catch (e) {
      print('Error creating party pack invitation: $e');
      throw e;
    }
  }

  Future<void> _removePartyPackMember() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            _isMutualPartyPack
                ? 'Leave Party Pack'
                : 'Cancel Party Pack Request',
            style: TextStyle(color: AppColors.textPrimary),
          ),
          content: Text(
            _isMutualPartyPack
                ? 'Are you sure you want to leave your party pack with $_currentPartyPackMember?'
                : 'Are you sure you want to cancel your party pack request to $_currentPartyPackMember?',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Cancel',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _performRemovePartyPackMember();
              },
              child: Text(
                _isMutualPartyPack ? 'Leave' : 'Cancel',
                style: TextStyle(color: AppColors.error),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performRemovePartyPackMember() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authProvider = Provider.of<app_auth.AuthProvider>(
        context,
        listen: false,
      );
      final user = authProvider.currentUser;

      if (user != null) {
        final currentUserEmail = user.email;

        // Remove from designated member's incoming list
        if (_currentPartyPackMember != null && currentUserEmail != null) {
          await _updateIncomingDesignations(
            targetUserEmail: _currentPartyPackMember!,
            designatingUserEmail: currentUserEmail,
            isAdding: false,
          );
        }

        // Remove current user's designation
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.id)
            .update({
              'partyPackMemberEmail': FieldValue.delete(),
              'updatedAt': FieldValue.serverTimestamp(),
            });

        setState(() {
          _currentPartyPackMember = null;
          _isMutualPartyPack = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Party pack member removed'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to remove party pack member: ${e.toString()}';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to remove party pack member: ${e.toString()}',
            ),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showSquadsInfo() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.help_outline, color: AppColors.primary, size: 24),
              const SizedBox(width: 8),
              const Text('How does Squads work?'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSquadInfoSection(
                  icon: Icons.group,
                  title: 'Squad Formation',
                  description:
                      'Squads are formed automatically based on your compatibility preferences and matching criteria. Squad matching will begin when enough people sign up.',
                ),
                const SizedBox(height: 16),
                _buildSquadInfoSection(
                  icon: Icons.people_alt,
                  title: 'Party Pack System',
                  description:
                      'Designate a party pack partner to be matched together in the same squad. This ensures you\'re grouped with someone you know.',
                ),
                const SizedBox(height: 16),
                _buildSquadInfoSection(
                  icon: Icons.handshake,
                  title: 'Mutual Selection',
                  description:
                      'Party pack partnerships require mutual agreement - both people must select each other to be confirmed as partners.',
                ),
                const SizedBox(height: 16),
                _buildSquadInfoSection(
                  icon: Icons.notifications,
                  title: 'Incoming Requests',
                  description:
                      'See who wants to be your party pack partner and accept or decline their requests.',
                ),
                const SizedBox(height: 16),
                _buildSquadInfoSection(
                  icon: Icons.chat,
                  title: 'Squad Chat',
                  description:
                      'Once in a squad, you can chat with your squad members and plan activities together.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Got it!'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSquadInfoSection({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
