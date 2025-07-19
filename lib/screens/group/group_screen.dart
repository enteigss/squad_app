import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../models/user_model.dart';
import '../../widgets/custom_button.dart';
import '../../utils/colors.dart';
import '../profile/profile_detail_screen.dart';
import '../../services/firestore_service.dart';
import '../../providers/auth_provider.dart';

class GroupScreen extends StatefulWidget {
  final String squadName;

  const GroupScreen({super.key, this.squadName = 'The Squad'});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  late List<UserModel> members;
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    members = _getMockMembers();
  }

  Future<List<UserModel>> _getGroupMembers() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.id;

    if (currentUserId == null) {
      return [];
    }

    return await _firestoreService.getGroupMembers(currentUserId);
  }

  void _openGroupChat() {
    context.push('/chat');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        title: Text(
          widget.squadName,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Chat Button Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: CustomButton(
              text: 'Open Group Chat',
              onPressed: _openGroupChat,
              width: double.infinity,
              height: 48,
              icon: const Icon(
                Icons.chat_bubble_outline,
                color: AppColors.onPrimary,
                size: 20,
              ),
            ),
          ),

          // Members Section
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Members (${members.length})',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Members List
                  Expanded(
                    child: FutureBuilder<List<UserModel>>(
                      future: _getGroupMembers(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        if (snapshot.hasError) {
                          return Center(
                            child: Text('Error: ${snapshot.error}'),
                          );
                        }

                        final members = snapshot.data ?? [];

                        return ListView.builder(
                          itemCount: members.length,
                          itemBuilder: (context, index) {
                            final member = members[index];
                            return _buildMemberCard(member);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberCard(UserModel member) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        elevation: 2,
        shadowColor: Colors.black.withOpacity(0.05),
        child: InkWell(
          onTap: () => _onMemberTapped(member),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Profile Picture
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: AppColors.getAvatarColor(
                        member.displayName ?? member.username,
                      ),
                      child: member.photoUrl != null
                          ? ClipOval(
                              child: Image.network(
                                member.photoUrl!,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return _buildDefaultAvatar(member);
                                },
                              ),
                            )
                          : _buildDefaultAvatar(member),
                    ),
                    // Online indicator
                    if (member.isOnline)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: AppColors.onlineIndicator,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.surface,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(width: 16),

                // Member Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Name and Age
                      Row(
                        children: [
                          Text(
                            member.displayName ?? member.username,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(width: 8),
                          if (member.age != null)
                            Text(
                              '${member.age}',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.textSecondary),
                            ),
                        ],
                      ),

                      const SizedBox(height: 4),

                      // Location
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            member.location ?? 'Unknown location',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      // Interests
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: member.interests.map((interest) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              interest,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(
                                    color: AppColors.primary,
                                    fontSize: 12,
                                  ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onMemberTapped(UserModel member) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProfileDetailScreen(user: member),
      ),
    );
  }

  Widget _buildDefaultAvatar(UserModel member) {
    final String initials =
        member.displayName != null && member.displayName!.isNotEmpty
        ? member.displayName!.split(' ').map((n) => n[0]).join().toUpperCase()
        : member.username[0].toUpperCase();

    return Text(
      initials,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  List<UserModel> _getMockMembers() {
    return [
      UserModel(
        id: '1',
        email: 'alex.johnson@example.com',
        username: 'alex_johnson',
        displayName: 'Alex Johnson',
        age: 24,
        location: 'San Francisco, CA',
        interests: ['Photography', 'Hiking', 'Coffee'],
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
        lastSeen: DateTime.now(),
        isOnline: true,
        bio:
            'Love exploring the outdoors and capturing moments through my lens.',
        groupId: 'squad_1',
      ),
      UserModel(
        id: '2',
        email: 'sarah.chen@example.com',
        username: 'sarah_chen',
        displayName: 'Sarah Chen',
        age: 22,
        location: 'New York, NY',
        interests: ['Reading', 'Yoga', 'Cooking'],
        createdAt: DateTime.now().subtract(const Duration(days: 45)),
        lastSeen: DateTime.now().subtract(const Duration(hours: 2)),
        isOnline: false,
        bio:
            'Bookworm by day, chef by night. Always looking for new recipes to try!',
        groupId: 'squad_1',
      ),
      UserModel(
        id: '3',
        email: 'mike.rodriguez@example.com',
        username: 'mike_rodriguez',
        displayName: 'Mike Rodriguez',
        age: 26,
        location: 'Austin, TX',
        interests: ['Gaming', 'Music', 'Travel'],
        createdAt: DateTime.now().subtract(const Duration(days: 60)),
        lastSeen: DateTime.now().subtract(const Duration(minutes: 15)),
        isOnline: true,
        bio:
            'Gamer and music enthusiast. Currently planning my next adventure!',
        groupId: 'squad_1',
      ),
      UserModel(
        id: '4',
        email: 'emma.wilson@example.com',
        username: 'emma_wilson',
        displayName: 'Emma Wilson',
        age: 23,
        location: 'Seattle, WA',
        interests: ['Art', 'Dancing', 'Movies'],
        createdAt: DateTime.now().subtract(const Duration(days: 20)),
        lastSeen: DateTime.now().subtract(const Duration(hours: 5)),
        isOnline: false,
        bio: 'Creative soul who loves expressing through art and movement.',
        groupId: 'squad_1',
      ),
      UserModel(
        id: '5',
        email: 'david.kim@example.com',
        username: 'david_kim',
        displayName: 'David Kim',
        age: 25,
        location: 'Los Angeles, CA',
        interests: ['Fitness', 'Technology', 'Food'],
        createdAt: DateTime.now().subtract(const Duration(days: 90)),
        lastSeen: DateTime.now().subtract(const Duration(minutes: 30)),
        isOnline: true,
        bio:
            'Tech enthusiast and fitness lover. Always looking for the best food spots!',
        groupId: 'squad_1',
      ),
    ];
  }
}
