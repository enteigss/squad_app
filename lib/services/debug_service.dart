import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../models/post_chat_message.dart';
import '../constants/bu_locations.dart';

class DebugService {
  static final DebugService _instance = DebugService._internal();
  factory DebugService() => _instance;
  DebugService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'posts';
  final String _debugAuthorId = 'debug_user_sample';
  final String _chatPostIndex = '1'; // Basketball post for chat messages

  static const List<Map<String, dynamic>> _samplePosts = [
    {
      'title': 'Study Session at Mugar Library',
      'description': 'Looking for focused study partners for finals prep. Quiet group studying with occasional discussion breaks.',
      'authorName': 'Sarah Chen',
      'location': 'Mugar Memorial Library',
      'profile': {
        'username': 'sarahc_bu',
        'email': 'sarahc@bu.edu',
        'displayName': 'Sarah Chen',
        'bio': 'Pre-med student who loves quiet study sessions and good coffee ☕',
        'classYear': 'Sophomore',
        'location': 'Bay State Road Brownstones',
        'interests': ['Reading', 'Science', 'Coffee', 'Art', 'Study'],
        'gender': 'woman',
        'photoUrl': null,
      },
    },
    {
      'title': 'Basketball Pickup at FitRec',
      'description': 'Need players for a casual basketball game. All skill levels welcome, just looking to have fun and get some exercise.',
      'authorName': 'Marcus Johnson',
      'location': 'FitRec',
      'profile': {
        'username': 'marcusj_ball',
        'email': 'marcusj@bu.edu',
        'displayName': 'Marcus Johnson',
        'bio': 'Basketball enthusiast looking for pickup games. Always down for a good match! 🏀',
        'classYear': 'Junior',
        'location': 'Warren Towers',
        'interests': ['Sports', 'Basketball', 'Fitness', 'Music', 'Competition'],
        'gender': 'man',
        'photoUrl': null,
      },
    },
    {
      'title': 'Late Night Snacks at Warren',
      'description': 'Anyone hungry after studying? Let\'s grab some late night food and chat about life.',
      'authorName': 'Alex Rivera',
      'location': 'Warren Towers Dining Hall',
      'profile': {
        'username': 'alexr_foodie',
        'email': 'alexr@bu.edu',
        'displayName': 'Alex Rivera',
        'bio': 'Night owl who\'s always hungry after studying. Love trying new foods! 🌙🍕',
        'classYear': 'Senior',
        'location': 'Student Village (StuVi) I',
        'interests': ['Food', 'Movies', 'Gaming', 'Technology', 'Cooking'],
        'gender': 'non_binary',
        'photoUrl': null,
      },
    },
    {
      'title': 'Frisbee at BU Beach',
      'description': 'Chill ultimate frisbee session on the beach. Great way to de-stress and meet new people.',
      'authorName': 'Emma Thompson',
      'location': 'BU Beach',
      'profile': {
        'username': 'emmat_frisbee',
        'email': 'emmat@bu.edu',
        'displayName': 'Emma Thompson',
        'bio': 'Ultimate frisbee player and outdoor enthusiast. Love meeting new people! 🥏🌊',
        'classYear': 'Sophomore',
        'location': 'Sleeper Hall',
        'interests': ['Sports', 'Nature', 'Photography', 'Animals', 'Fitness'],
        'gender': 'woman',
        'photoUrl': null,
      },
    },
    {
      'title': 'Pool Tournament at GSU',
      'description': 'Competitive but friendly pool games. Prizes for winners and good vibes for everyone.',
      'authorName': 'Jordan Kim',
      'location': 'GSU',
      'profile': {
        'username': 'jordank_pool',
        'email': 'jordank@bu.edu',
        'displayName': 'Jordan Kim',
        'bio': 'Competitive gamer who loves a good challenge. Pool shark in training! 🎱',
        'classYear': 'Junior',
        'location': 'Myles Standish Hall',
        'interests': ['Gaming', 'Competition', 'Technology', 'Movies', 'Strategy'],
        'gender': 'man',
        'photoUrl': null,
      },
    },
  ];

  Future<void> createSamplePosts() async {
    if (!kDebugMode) {
      throw Exception('Sample posts can only be created in debug mode');
    }

    try {
      final now = DateTime.now();
      
      // First create user profiles
      await _createSampleUserProfiles();
      
      // Then create posts
      for (int i = 0; i < _samplePosts.length; i++) {
        final sample = _samplePosts[i];
        
        // Create posts with varying scheduled times
        DateTime scheduledTime;
        PostStatus status;
        
        switch (i) {
          case 0:
            // Upcoming in 2 hours
            scheduledTime = now.add(const Duration(hours: 2));
            status = PostStatus.upcoming;
            break;
          case 1:
            // Upcoming in 1 day
            scheduledTime = now.add(const Duration(days: 1));
            status = PostStatus.upcoming;
            break;
          case 2:
            // Ongoing (started 1 hour ago)
            scheduledTime = now.subtract(const Duration(hours: 1));
            status = PostStatus.ongoing;
            break;
          case 3:
            // Upcoming in 3 hours
            scheduledTime = now.add(const Duration(hours: 3));
            status = PostStatus.upcoming;
            break;
          case 4:
            // Upcoming tomorrow evening
            scheduledTime = now.add(const Duration(days: 1, hours: 6));
            status = PostStatus.upcoming;
            break;
          default:
            scheduledTime = now.add(const Duration(hours: 2));
            status = PostStatus.upcoming;
        }

        final docRef = _firestore.collection(_collection).doc();
        
        final post = Post(
          id: docRef.id,
          title: sample['title']!,
          description: sample['description']!,
          authorId: '${_debugAuthorId}_$i',
          authorName: sample['authorName']!,
          createdAt: now.subtract(Duration(minutes: i * 5)), // Stagger creation times
          scheduledTime: scheduledTime,
          status: status,
          participantIds: _generateParticipants(i),
          location: sample['location']!,
          maxParticipants: _generateMaxParticipants(i),
          genderPreferences: const ['Men'], // Set to Men only to prevent notifications
          deleted: false,
          isLocked: false,
        );

        await docRef.set(post.toMap());
        
        // Create sample chat for basketball post (index 1)
        if (i.toString() == _chatPostIndex) {
          await _createSampleChatMessages(docRef.id);
        }
      }

      debugPrint('Created ${_samplePosts.length} sample debug posts with profiles and chat');
    } catch (e) {
      throw Exception('Failed to create sample posts: $e');
    }
  }

  Future<void> deleteAllDebugPosts() async {
    if (!kDebugMode) {
      throw Exception('Debug posts can only be deleted in debug mode');
    }

    try {
      // Query for all posts created by debug authors
      final QuerySnapshot postsSnapshot = await _firestore
          .collection(_collection)
          .where('authorId', whereIn: [
            for (int i = 0; i < _samplePosts.length; i++) '${_debugAuthorId}_$i'
          ])
          .get();

      final batch = _firestore.batch();
      int deletedChats = 0;
      
      // Delete posts and their chat subcollections
      for (final doc in postsSnapshot.docs) {
        // Delete chat messages for this post
        final chatSnapshot = await _firestore
            .collection(_collection)
            .doc(doc.id)
            .collection('chat')
            .get();
        
        for (final chatDoc in chatSnapshot.docs) {
          batch.delete(chatDoc.reference);
          deletedChats++;
        }
        
        // Delete the post
        batch.delete(doc.reference);
      }
      
      // Delete debug user profiles
      for (int i = 0; i < _samplePosts.length; i++) {
        final userRef = _firestore.collection('users').doc('${_debugAuthorId}_$i');
        batch.delete(userRef);
      }

      await batch.commit();
      debugPrint('Deleted ${postsSnapshot.docs.length} debug posts, $deletedChats chat messages, and ${_samplePosts.length} user profiles');
    } catch (e) {
      throw Exception('Failed to delete debug posts: $e');
    }
  }

  List<String> _generateParticipants(int index) {
    switch (index) {
      case 0:
        return ['${_debugAuthorId}_$index']; // Just author
      case 1:
        return ['${_debugAuthorId}_$index', 'participant_1', 'participant_2']; // 3 people
      case 2:
        return ['${_debugAuthorId}_$index', 'participant_3']; // 2 people
      case 3:
        return ['${_debugAuthorId}_$index', 'participant_4', 'participant_5', 'participant_6']; // 4 people
      case 4:
        return ['${_debugAuthorId}_$index']; // Just author
      default:
        return ['${_debugAuthorId}_$index'];
    }
  }

  int _generateMaxParticipants(int index) {
    switch (index) {
      case 0:
        return 6; // Study group
      case 1:
        return 10; // Basketball
      case 2:
        return 4; // Small dining group
      case 3:
        return 8; // Frisbee
      case 4:
        return 12; // Pool tournament
      default:
        return 6;
    }
  }

  Future<void> _createSampleUserProfiles() async {
    final now = DateTime.now();
    
    for (int i = 0; i < _samplePosts.length; i++) {
      final sample = _samplePosts[i];
      final profileData = sample['profile'] as Map<String, dynamic>;
      
      final user = UserModel(
        id: '${_debugAuthorId}_$i',
        email: profileData['email'] as String,
        username: profileData['username'] as String,
        displayName: profileData['displayName'] as String,
        photoUrl: profileData['photoUrl'] as String?,
        bio: profileData['bio'] as String,
        classYear: profileData['classYear'] as String,
        location: profileData['location'] as String,
        interests: List<String>.from(profileData['interests']),
        gender: profileData['gender'] as String,
        createdAt: now.subtract(Duration(days: 30 + i * 5)), // Created 30+ days ago
        lastSeen: now.subtract(Duration(minutes: 10 + i * 2)), // Recently active
        isOnline: i % 2 == 0, // Some online, some offline
        hasCreatedProfile: true,
        authProvider: 'google',
        isEmailVerified: true,
      );
      
      await _firestore
          .collection('users')
          .doc('${_debugAuthorId}_$i')
          .set(user.toMap());
    }
    
    debugPrint('Created ${_samplePosts.length} sample user profiles');
  }

  Future<void> _createSampleChatMessages(String postId) async {
    final now = DateTime.now();
    
    final chatMessages = [
      {
        'senderId': '${_debugAuthorId}_1', // Marcus (author)
        'senderName': 'Marcus Johnson',
        'content': 'Hey everyone! Looking forward to some good basketball 🏀',
        'timestamp': now.subtract(const Duration(hours: 2)),
      },
      {
        'senderId': '${_debugAuthorId}_0', // Sarah joined
        'senderName': 'Sarah Chen',
        'content': 'Just joined! I\'m not great but I love playing',
        'timestamp': now.subtract(const Duration(hours: 1, minutes: 45)),
      },
      {
        'senderId': '${_debugAuthorId}_1',
        'senderName': 'Marcus Johnson',
        'content': 'No worries Sarah! All skill levels welcome',
        'timestamp': now.subtract(const Duration(hours: 1, minutes: 40)),
      },
      {
        'senderId': '${_debugAuthorId}_2', // Alex joined
        'senderName': 'Alex Rivera',
        'content': 'Count me in! What time are we meeting?',
        'timestamp': now.subtract(const Duration(hours: 1, minutes: 30)),
      },
      {
        'senderId': '${_debugAuthorId}_1',
        'senderName': 'Marcus Johnson',
        'content': 'Tomorrow at 3pm. Meet at the main gym entrance',
        'timestamp': now.subtract(const Duration(hours: 1, minutes: 25)),
      },
      {
        'senderId': '${_debugAuthorId}_3', // Emma joined
        'senderName': 'Emma Thompson',
        'content': 'Perfect! I\'ll bring some water bottles',
        'timestamp': now.subtract(const Duration(hours: 1, minutes: 15)),
      },
      {
        'senderId': '${_debugAuthorId}_0',
        'senderName': 'Sarah Chen',
        'content': 'Should I bring anything else?',
        'timestamp': now.subtract(const Duration(hours: 1, minutes: 10)),
      },
      {
        'senderId': '${_debugAuthorId}_1',
        'senderName': 'Marcus Johnson',
        'content': 'Just yourself and some energy! See you all tomorrow 💪',
        'timestamp': now.subtract(const Duration(hours: 1, minutes: 5)),
      },
      {
        'senderId': '${_debugAuthorId}_2',
        'senderName': 'Alex Rivera',
        'content': 'Can\'t wait! It\'s been too long since I played',
        'timestamp': now.subtract(const Duration(minutes: 45)),
      },
      {
        'senderId': '${_debugAuthorId}_3',
        'senderName': 'Emma Thompson',
        'content': 'Same here! This is going to be fun 🔥',
        'timestamp': now.subtract(const Duration(minutes: 30)),
      },
    ];
    
    final batch = _firestore.batch();
    
    for (int i = 0; i < chatMessages.length; i++) {
      final messageData = chatMessages[i];
      final messageRef = _firestore
          .collection(_collection)
          .doc(postId)
          .collection('chat')
          .doc();
      
      final message = PostChatMessage(
        id: messageRef.id,
        postId: postId,
        senderId: messageData['senderId'] as String,
        senderName: messageData['senderName'] as String,
        content: messageData['content'] as String,
        type: PostChatMessageType.text,
        timestamp: messageData['timestamp'] as DateTime,
        readBy: [], // No read receipts for simplicity
      );
      
      batch.set(messageRef, message.toMap());
    }
    
    await batch.commit();
    debugPrint('Created ${chatMessages.length} sample chat messages for post $postId');
  }
}