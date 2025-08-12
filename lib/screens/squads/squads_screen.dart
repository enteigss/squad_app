import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
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

  @override
  void initState() {
    super.initState();
    _loadCurrentPartyPackMember();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrentPartyPackMember() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
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
          final incoming = List<String>.from(data['incomingPartyPackRequests'] ?? []);
          
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
  
  Future<void> _checkMutualDesignation(String currentUserEmail, String designatedEmail) async {
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
            'incomingPartyPackRequests': FieldValue.arrayUnion([designatingUserEmail]),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          // Remove from their incoming designations
          await targetUserDoc.reference.update({
            'incomingPartyPackRequests': FieldValue.arrayRemove([designatingUserEmail]),
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
      ),
      body: Consumer<AuthProvider>(
        builder: (context, authProvider, child) {
          final user = authProvider.currentUser;
          final isInSquad = user?.groupId != null && user!.groupId!.isNotEmpty;

          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Squad Status Section
                  _buildSquadStatusSection(isInSquad, user?.groupId),

                  const SizedBox(height: 20),

                  // Current Party Pack Member Status
                  _buildCurrentPartyPackSection(),

                  const SizedBox(height: 20),

                  // Designate Party Pack Member Section
                  _buildDesignatePartyPackSection(),

                  if (_incomingDesignations.isNotEmpty) ...[
                    const SizedBox(height: 20),

                    // Incoming Party Pack Requests Section
                    _buildIncomingRequestsSection(),
                  ],

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
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
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSquadStatusSection(bool isInSquad, String? groupId) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
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
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isInSquad
                  ? AppColors.success.withValues(alpha: 0.1)
                  : AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isInSquad
                    ? AppColors.success.withValues(alpha: 0.3)
                    : AppColors.error.withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  isInSquad ? Icons.check_circle : Icons.cancel,
                  color: isInSquad ? AppColors.success : AppColors.error,
                  size: 36,
                ),
                const SizedBox(height: 8),
                Text(
                  isInSquad ? 'You\'re in a Squad!' : 'Not in a Squad',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isInSquad ? AppColors.success : AppColors.error,
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
    final hasPartyPackMember = _currentPartyPackMember != null && _currentPartyPackMember!.isNotEmpty;
    
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
      statusDescription = 'You and ${_currentPartyPackMember!} are now party pack partners';
    } else {
      statusColor = AppColors.primary;
      backgroundColor = AppColors.primary.withValues(alpha: 0.1);
      borderColor = AppColors.primary.withValues(alpha: 0.3);
      statusIcon = Icons.hourglass_empty;
      statusTitle = 'Waiting for Response';
      statusDescription = 'Waiting for ${_currentPartyPackMember!} to select you back to form a party pack';
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
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
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: borderColor,
                width: 1,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  statusIcon,
                  color: statusColor,
                  size: 36,
                ),
                const SizedBox(height: 8),
                Text(
                  statusTitle,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (hasPartyPackMember) ...[
                  const SizedBox(height: 6),
                  if (!_isMutualPartyPack) ...[
                    Text(
                      _currentPartyPackMember!,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    statusDescription,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _removePartyPackMember,
                    icon: const Icon(Icons.remove_circle_outline),
                    label: Text(_isMutualPartyPack ? 'Leave Party Pack' : 'Cancel Request'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
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
          const SizedBox(height: 12),
          Text(
            'Enter the email of someone you want to party pack with. This person will be your designated partner for activities and events.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          CustomTextField(
            controller: _emailController,
            hint: 'Enter their email address',
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter an email address';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          CustomButton(
            text: _isLoading ? 'Saving...' : 'Set Party Pack Member',
            onPressed: _isLoading ? null : _setPartyPackMember,
            width: double.infinity,
            height: 40,
            isLoading: _isLoading,
          ),
        ],
      ),
    );
  }

  Widget _buildIncomingRequestsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_active, color: AppColors.primary, size: 24),
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
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          ..._incomingDesignations.map((email) => _buildIncomingRequestCard(email)).toList(),
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
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.person,
                color: AppColors.primary,
                size: 20,
              ),
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
                    icon: const Icon(Icons.check, color: Colors.white, size: 16),
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
                    icon: const Icon(Icons.close, color: Colors.white, size: 16),
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
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
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
            .update({
          'incomingPartyPackRequests': _incomingDesignations,
        });

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
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
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
            .update({
          'incomingPartyPackRequests': _incomingDesignations,
        });

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
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser;
      
      if (user != null) {
        final newMemberEmail = _emailController.text.trim();
        final currentUserEmail = user.email;
        
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

        // Add new designation to new member's incoming list
        if (currentUserEmail != null) {
          await _updateIncomingDesignations(
            targetUserEmail: newMemberEmail,
            designatingUserEmail: currentUserEmail,
            isAdding: true,
          );
        }

        setState(() {
          _currentPartyPackMember = newMemberEmail;
          _emailController.clear();
        });

        // Check for mutual designation with the new member
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

  Future<void> _removePartyPackMember() async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            _isMutualPartyPack ? 'Leave Party Pack' : 'Cancel Party Pack Request',
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
                style: TextStyle(color: AppColors.error)
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
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
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
            content: Text('Failed to remove party pack member: ${e.toString()}'),
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
}