import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import 'post_chat_service.dart';
import 'firestore_service.dart';
import 'feedback_service.dart';

class PostService {
  static final PostService _instance = PostService._internal();
  factory PostService() => _instance;
  PostService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'posts';
  final PostChatService _chatService = PostChatService();
  final FirestoreService _firestoreService = FirestoreService();
  final FeedbackService _feedbackService = FeedbackService();

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

  // Delete post with feedback collection for other participants (excluding author)
  Future<void> deletePostWithFeedback(
    String postId,
    String authorId, {
    bool? authorDidMeetup,
    String? authorAdditionalFeedback,
  }) async {
    try {
      // Get the post first to check if we need to create feedback prompts
      final post = await getPost(postId);
      debugPrint(
        'DeletePostWithFeedback: Retrieved post $postId, participants: ${post?.participantIds.length}',
      );

      await _firestore.collection(_collection).doc(postId).update({
        'deleted': true,
      });

      // If the post had participants and wasn't already completed, handle feedback
      debugPrint(
        'DeletePostWithFeedback: Checking feedback conditions - feedbackCollected: ${post?.feedbackCollected}, status: ${post?.status}, participants: ${post?.participantIds.length}',
      );
      if (post != null &&
          !post.feedbackCollected &&
          post.status != PostStatus.completed &&
          post.participantIds.length >= 1) {
        // TODO: Change back to >= 2 for production

        // Mark as feedback collected
        await _firestore.collection(_collection).doc(postId).update({
          'feedbackCollected': true,
        });

        // If author provided immediate feedback, save it
        if (authorDidMeetup != null) {
          await _feedbackService.submitFeedback(
            hangoutId: postId,
            userId: authorId,
            hangoutTitle: post.title,
            didMeetup: authorDidMeetup,
            additionalFeedback: authorAdditionalFeedback,
          );
          debugPrint(
            'DeletePostWithFeedback: Saved immediate author feedback for $authorId',
          );
        }

        // Create prompts for other participants (exclude author since they gave immediate feedback)
        final otherParticipants = post.participantIds
            .where((id) => id != authorId)
            .toList();
        debugPrint(
          'DeletePostWithFeedback: Creating prompts for ${otherParticipants.length} other participants: $otherParticipants',
        );

        if (otherParticipants.isNotEmpty) {
          final deletedPost = post.copyWith(
            deleted: true,
            feedbackCollected: true,
            participantIds:
                otherParticipants, // Only create prompts for other participants
          );

          // Create feedback prompts for other participants
          _feedbackService
              .createFeedbackPromptsForCompletedHangout(deletedPost)
              .catchError((e) {
                debugPrint(
                  'Failed to create feedback prompts for deleted post $postId: $e',
                );
              });
        }
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

    // If post accepts "Anyone", it matches any user
    if (post.genderPreferences.contains('Anyone')) {
      return true;
    }

    // If user hasn't specified gender, they can only see "Anyone" posts
    if (userGender == null || userGender == 'prefer_not_to_say') {
      return false; // Already checked "Anyone" above
    }

    // Map user gender to post preference format
    String expectedPreference = '';
    switch (userGender) {
      case 'woman':
        expectedPreference = 'Women only';
        break;
      case 'man':
        expectedPreference = 'Men only';
        break;
      case 'non_binary':
        expectedPreference = 'Non-binary only';
        break;
      default:
        return false;
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

              // Create feedback prompts asynchronously (don't block the batch)
              _feedbackService
                  .createFeedbackPromptsForCompletedHangout(completedPost)
                  .catchError((e) {
                    debugPrint(
                      'Failed to create feedback prompts for ${post.id}: $e',
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
