import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import 'post_chat_service.dart';
import 'firestore_service.dart';

class PostService {
  static final PostService _instance = PostService._internal();
  factory PostService() => _instance;
  PostService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'posts';
  final PostChatService _chatService = PostChatService();
  final FirestoreService _firestoreService = FirestoreService();

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

  // Get all posts with real-time updates
  Stream<List<Post>> getPosts() {
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
              .where((post) => !post.deleted && post.status == status)
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
    final now = DateTime.now();
    return _firestore
        .collection(_collection)
        .orderBy('scheduledTime', descending: false)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Post.fromMap(doc.data()))
              .where((post) {
                // Filter out deleted posts
                if (post.deleted) return false;
                
                // Only show posts with upcoming status
                if (post.status != PostStatus.upcoming) return false;
                
                // Filter for upcoming posts (scheduled for the future)
                if (post.scheduledTime == null) return false;
                
                return post.scheduledTime!.isAfter(now);
              })
              .toList();
        });
  }

  // Get ongoing posts (posts scheduled within the last 4 hours)
  Stream<List<Post>> getOngoingPosts() {
    final now = DateTime.now();
    final fourHoursAgo = now.subtract(const Duration(hours: 4));

    return _firestore
        .collection(_collection)
        .orderBy('scheduledTime', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => Post.fromMap(doc.data()))
              .where((post) {
                // Filter out deleted posts
                if (post.deleted) return false;
                
                // Only show posts with ongoing status
                if (post.status != PostStatus.ongoing) return false;
                
                // Filter for ongoing posts (scheduled within last 4 hours)
                if (post.scheduledTime == null) return false;
                
                return post.scheduledTime!.isAfter(fourHoursAgo) &&
                       post.scheduledTime!.isBefore(now.add(const Duration(minutes: 1)));
              })
              .toList();
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
        transaction.update(docRef, {'participantIds': updatedParticipants});
      });
      
      // Send chat notification that user joined
      try {
        final user = await _firestoreService.getUser(userId);
        final userName = user?.displayName ?? 'Unknown User';
        await _chatService.handleUserJoined(
          postId: postId,
          userName: userName,
        );
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
        transaction.update(docRef, {'participantIds': updatedParticipants});
      });
      
      // Send chat notification that user left
      try {
        final user = await _firestoreService.getUser(userId);
        final userName = user?.displayName ?? 'Unknown User';
        await _chatService.handleUserLeft(
          postId: postId,
          userName: userName,
        );
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
      await _firestore
          .collection(_collection)
          .doc(postId)
          .update({'deleted': true});
    } catch (e) {
      throw Exception('Failed to delete post: $e');
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
            (post.title.toLowerCase().contains(searchQuery) ||
             post.description.toLowerCase().contains(searchQuery));
      }).toList();
    });
  }

  // Get posts filtered by gender preferences
  Stream<List<Post>> getPostsByGenderPreference(List<String> userGenders) {
    return getPosts().map((posts) {
      return posts.where((post) {
        // Skip deleted posts
        if (post.deleted) return false;
        
        // If post accepts "Anyone", it matches any user
        if (post.genderPreferences.contains('Anyone')) {
          return true;
        }

        // Check if user's gender matches any of the post's preferences
        return userGenders.any(
          (userGender) => post.genderPreferences.contains(userGender),
        );
      }).toList();
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
          
          // If post just became completed, archive the chat
          if (newStatus == PostStatus.completed && post.status != PostStatus.completed) {
            _chatService.archiveChat(post.id);
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
