import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/post_model.dart';
import 'post_chat_service.dart';
import 'firestore_service.dart';
import 'feedback_service.dart';
import 'analytics_service.dart';

class PostService {
  static final PostService _instance = PostService._internal();
  factory PostService() => _instance;
  PostService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'posts';
  final PostChatService _chatService = PostChatService();
  final FirestoreService _firestoreService = FirestoreService();
  final FeedbackService _feedbackService = FeedbackService();
  final AnalyticsService _analyticsService = AnalyticsService();

  // Create a new post
  Future<String> createPost(Post post) async {
    try {
      final docRef = _firestore.collection(_collection).doc();
      final postWithId = post.copyWith(id: docRef.id);

      await docRef.set(postWithId.toMap());

      // Initialize chat for the new post
      await _chatService.initializeChat(docRef.id);

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create post: $e');
    }
  }

  // Get all posts with real-time updates (excludes locked posts for discovery)
  Stream<List<Post>> getPosts() {
    return _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Post.fromMap(doc.data()))
              .where((post) => !post.deleted && !post.isLocked)
              .toList();
        });
  }

  // Get all posts including locked ones (for user's own hangouts)
  Stream<List<Post>> getAllPosts() {
    return _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Post.fromMap(doc.data()))
              .where((post) => !post.deleted)
              .toList();
        });
  }

  // Get posts filtered by status
  Stream<List<Post>> getPostsByStatus(PostStatus status) {
    return _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Post.fromMap(doc.data()))
              .where(
                (post) =>
                    !post.deleted && !post.isLocked && post.status == status,
              )
              .toList();
        });
  }

  // Get posts by a specific user
  Stream<List<Post>> getUserPosts(String userId) {
    return _firestore
        .collection(_collection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Post.fromMap(doc.data()))
              .where((post) => !post.deleted && post.authorId == userId)
              .toList();
        });
  }

  // Get upcoming posts (posts scheduled for the future)
  Stream<List<Post>> getUpcomingPosts() {
    return _firestore
        .collection(_collection)
        .orderBy('scheduledTime', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Post.fromMap(doc.data())).where((
            post,
          ) {
            // Filter out deleted and locked posts
            if (post.deleted || post.isLocked) return false;

            // Use dynamic status calculation
            return post.dynamicStatus == PostStatus.upcoming;
          }).toList();
        });
  }

  // Get ongoing posts (posts scheduled within the last 4 hours)
  Stream<List<Post>> getOngoingPosts() {
    return _firestore
        .collection(_collection)
        .orderBy('scheduledTime', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => Post.fromMap(doc.data())).where((
            post,
          ) {
            // Filter out deleted and locked posts
            if (post.deleted || post.isLocked) return false;

            // Use dynamic status calculation
            return post.dynamicStatus == PostStatus.ongoing;
          }).toList();
        });
  }

  // Helper method to check gender compatibility
  bool _isUserGenderCompatible(Post post, String? userGender) {
    // If user hasn't specified gender, they can only join posts that include ALL three options
    if (userGender == null || userGender == 'prefer_not_to_say') {
      return post.genderPreferences.contains('Men') &&
             post.genderPreferences.contains('Women') &&
             post.genderPreferences.contains('Other');
    }
    
    // Map user gender to preference format
    String expectedPreference = '';
    switch (userGender) {
      case 'woman':
        expectedPreference = 'Women';
        break;
      case 'man':
        expectedPreference = 'Men';
        break;
      case 'non_binary':
        expectedPreference = 'Other';
        break;
      default:
        // For any other gender identities, map to 'Other'
        expectedPreference = 'Other';
        break;
    }
    
    // Check if post's gender preferences include the user's gender
    return post.genderPreferences.contains(expectedPreference);
  }

  // Join a post
  Future<void> joinPost(String postId, String userId) async {
    try {
      final docRef = _firestore.collection(_collection).doc(postId);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          throw Exception('Post not found');
        }

        final post = Post.fromMap(snapshot.data()!);

        // Check if user is already a participant
        if (post.participantIds.contains(userId)) {
          throw Exception('User already joined this post');
        }

        // Check if post is full
        if (post.participantIds.length >= post.maxParticipants) {
          throw Exception('Post is full');
        }

        // Get user data to check gender compatibility
        final userDoc = await transaction.get(_firestore.collection('users').doc(userId));
        if (!userDoc.exists) {
          throw Exception('User not found');
        }

        final userData = userDoc.data()!;
        final userGender = userData['gender'] as String?;

        // Check gender compatibility
        if (!_isUserGenderCompatible(post, userGender)) {
          throw Exception('Gender preferences do not match');
        }

        // Add user to participants
        final updatedParticipants = [...post.participantIds, userId];
        final updates = <String, dynamic>{
          'participantIds': updatedParticipants,
        };

        // Check if post should be locked after adding this user
        if (updatedParticipants.length >= post.maxParticipants) {
          updates['isLocked'] = true;
        }

        transaction.update(docRef, updates);
      });

      // Send chat notification that user joined
      try {
        final user = await _firestoreService.getUser(userId);
        final userName = user?.displayName ?? 'Unknown User';
        await _chatService.handleUserJoined(postId: postId, userName: userName);
      } catch (e) {
        // Don't fail the join operation if chat notification fails
        debugPrint('Failed to send chat join notification: $e');
      }
    } catch (e) {
      throw Exception('Failed to join post: $e');
    }
  }

  // Leave a post
  Future<void> leavePost(String postId, String userId) async {
    try {
      final docRef = _firestore.collection(_collection).doc(postId);

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) {
          throw Exception('Post not found');
        }

        final post = Post.fromMap(snapshot.data()!);

        // Check if user is a participant
        if (!post.participantIds.contains(userId)) {
          throw Exception('User is not a participant of this post');
        }

        // Remove user from participants
        final updatedParticipants = post.participantIds
            .where((id) => id != userId)
            .toList();
        final updates = <String, dynamic>{
          'participantIds': updatedParticipants,
        };

        // Check if post should be unlocked after removing this user
        // Only unlock if it was previously locked due to being full (not manually locked)
        if (post.isLocked &&
            post.participantIds.length == post.maxParticipants) {
          // This means it was auto-locked when full, so we can auto-unlock
          if (updatedParticipants.length < post.maxParticipants) {
            updates['isLocked'] = false;
          }
        }

        transaction.update(docRef, updates);
      });

      // Send chat notification that user left
      try {
        final user = await _firestoreService.getUser(userId);
        final userName = user?.displayName ?? 'Unknown User';
        await _chatService.handleUserLeft(postId: postId, userName: userName);
      } catch (e) {
        // Don't fail the leave operation if chat notification fails
        debugPrint('Failed to send chat leave notification: $e');
      }
    } catch (e) {
      throw Exception('Failed to leave post: $e');
    }
  }

  // Update a post
  Future<void> updatePost(Post post) async {
    try {
      await _firestore
          .collection(_collection)
          .doc(post.id)
          .update(post.toMap());
    } catch (e) {
      throw Exception('Failed to update post: $e');
    }
  }

  // Soft delete a post (mark as deleted)
  Future<void> deletePost(String postId) async {
    try {
      await _firestore.collection(_collection).doc(postId).update({
        'deleted': true,
      });
    } catch (e) {
      throw Exception('Failed to delete post: $e');
    }
  }

  // Check if author needs to provide feedback before deletion
  Future<bool> doesAuthorNeedFeedbackForDeletion(String postId, String authorId) async {
    try {
      // Check if author has already provided feedback
      final hasProvidedFeedback = await _feedbackService.hasAuthorProvidedFeedback(postId, authorId);
      return !hasProvidedFeedback;
    } catch (e) {
      debugPrint('Error checking if author needs feedback: $e');
      return true; // Default to showing dialog if uncertain
    }
  }

  // Delete post with feedback collection from author
  Future<void> deletePostWithFeedback(
    String postId,
    String authorId, {
    bool? authorDidMeetup,
  }) async {
    try {
      // Get the post first
      final post = await getPost(postId);
      debugPrint('DeletePostWithFeedback: Retrieved post $postId');

      await _firestore.collection(_collection).doc(postId).update({
        'deleted': true,
      });

      // If author provided feedback, save it and track analytics
      if (post != null && authorDidMeetup != null) {
        await _feedbackService.submitFeedback(
          hangoutId: postId,
          userId: authorId,
          hangoutTitle: post.title,
          didMeetup: authorDidMeetup,
          additionalFeedback: null,
        );

        await _analyticsService.trackMeetupSuccess(authorDidMeetup);
        debugPrint('DeletePostWithFeedback: Saved author feedback for $authorId');
      }
    } catch (e) {
      throw Exception('Failed to delete post with feedback: $e');
    }
  }

  // Lock a post (hide from discovery but keep group functional)
  Future<void> lockPost(String postId) async {
    try {
      await _firestore.collection(_collection).doc(postId).update({
        'isLocked': true,
      });
    } catch (e) {
      throw Exception('Failed to lock post: $e');
    }
  }

  // Unlock a post (make visible for discovery again)
  Future<void> unlockPost(String postId) async {
    try {
      await _firestore.collection(_collection).doc(postId).update({
        'isLocked': false,
      });
    } catch (e) {
      throw Exception('Failed to unlock post: $e');
    }
  }

  // Get a single post by ID
  Future<Post?> getPost(String postId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(postId).get();
      if (doc.exists) {
        return Post.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get post: $e');
    }
  }

  // Search posts by title or description
  Stream<List<Post>> searchPosts(String query) {
    // Note: Firestore doesn't support full-text search natively
    // This is a simple implementation that filters on the client side
    // For production, consider using Algolia or similar service
    return getPosts().map((posts) {
      return posts.where((post) {
        final searchQuery = query.toLowerCase();
        return !post.deleted &&
            !post.isLocked &&
            (post.title.toLowerCase().contains(searchQuery) ||
                post.description.toLowerCase().contains(searchQuery));
      }).toList();
    });
  }

  // Helper method to check if user can see a post based on gender
  bool _canUserSeePost(Post post, String? userGender) {
    // Skip deleted posts
    if (post.deleted) return false;

    // If user hasn't specified gender, they can only see posts that include ALL three options
    if (userGender == null || userGender == 'prefer_not_to_say') {
      return post.genderPreferences.contains('Men') &&
             post.genderPreferences.contains('Women') &&
             post.genderPreferences.contains('Non-binary');
    }

    // Map user gender to new preference format
    String expectedPreference = '';
    switch (userGender) {
      case 'woman':
        expectedPreference = 'Women';
        break;
      case 'man':
        expectedPreference = 'Men';
        break;
      case 'non_binary':
        expectedPreference = 'Non-binary';
        break;
      default:
        // For any other gender identities, map to 'Non-binary'
        expectedPreference = 'Non-binary';
        break;
    }

    // Check if post's gender preferences include the user's gender
    return post.genderPreferences.contains(expectedPreference);
  }

  // Get posts filtered by gender preferences
  Stream<List<Post>> getPostsByGenderPreference(String? userGender) {
    return getPosts().map((posts) {
      return posts.where((post) => _canUserSeePost(post, userGender)).toList();
    });
  }

  // Batch update post statuses based on scheduled time
  Future<void> updatePostStatuses() async {
    try {
      final now = DateTime.now();
      final fourHoursAgo = now.subtract(const Duration(hours: 4));

      // Get all posts that might need status updates
      final snapshot = await _firestore.collection(_collection).get();

      final batch = _firestore.batch();
      bool hasUpdates = false;

      for (final doc in snapshot.docs) {
        final post = Post.fromMap(doc.data());

        // Skip deleted posts
        if (post.deleted) continue;

        final newStatus = _calculatePostStatus(post, now, fourHoursAgo);

        if (newStatus != post.status) {
          batch.update(doc.reference, {'status': newStatus.name});
          hasUpdates = true;

          // If post just became completed, archive the chat and create feedback prompts
          if (newStatus == PostStatus.completed &&
              post.status != PostStatus.completed) {
            _chatService.archiveChat(post.id);

            // Create feedback prompts if not already collected
            if (!post.feedbackCollected) {
              // Create the updated post object to pass to feedback service
              final completedPost = post.copyWith(
                status: newStatus,
                feedbackCollected: true,
              );

              // Mark as feedback collected in the database
              batch.update(doc.reference, {'feedbackCollected': true});

              // Create feedback prompt for author only
              _feedbackService
                  .createFeedbackPromptForAuthor(completedPost)
                  .catchError((e) {
                    debugPrint(
                      'Failed to create feedback prompt for author of ${post.id}: $e',
                    );
                  });
            }
          }
        }
      }

      if (hasUpdates) {
        await batch.commit();
      }
    } catch (e) {
      throw Exception('Failed to update post statuses: $e');
    }
  }

  PostStatus _calculatePostStatus(
    Post post,
    DateTime now,
    DateTime fourHoursAgo,
  ) {
    if (post.scheduledTime == null) return post.status;

    if (post.scheduledTime!.isAfter(now)) {
      return PostStatus.upcoming;
    } else if (post.scheduledTime!.isAfter(fourHoursAgo)) {
      return PostStatus.ongoing;
    } else {
      return PostStatus.completed;
    }
  }
}
