import 'package:flutter/foundation.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';
import 'dart:async';

class PostProvider with ChangeNotifier {
  final PostService _postService = PostService();
  
  List<Post> _posts = [];
  List<Post> _upcomingPosts = [];
  List<Post> _ongoingPosts = [];
  List<Post> _userPosts = [];
  
  bool _isLoading = false;
  String? _error;
  
  StreamSubscription<List<Post>>? _postsSubscription;
  StreamSubscription<List<Post>>? _upcomingSubscription;
  StreamSubscription<List<Post>>? _ongoingSubscription;
  StreamSubscription<List<Post>>? _userPostsSubscription;

  // Getters
  List<Post> get posts => _posts;
  List<Post> get upcomingPosts => _upcomingPosts;
  List<Post> get ongoingPosts => _ongoingPosts;
  List<Post> get userPosts => _userPosts;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Initialize and start listening to posts
  Future<void> initialize() async {
    _setLoading(true);
    _clearError();
    
    try {
      // Subscribe to all posts
      _postsSubscription = _postService.getPosts().listen(
        (posts) {
          _posts = posts;
          notifyListeners();
        },
        onError: (error) {
          _setError('Failed to load posts: $error');
        },
      );

      // Subscribe to upcoming posts
      _upcomingSubscription = _postService.getUpcomingPosts().listen(
        (posts) {
          _upcomingPosts = posts;
          notifyListeners();
        },
      );

      // Subscribe to ongoing posts
      _ongoingSubscription = _postService.getOngoingPosts().listen(
        (posts) {
          _ongoingPosts = posts;
          notifyListeners();
        },
      );

    } catch (e) {
      _setError('Failed to initialize posts: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Load user-specific posts
  Future<void> loadUserPosts(String userId) async {
    try {
      _userPostsSubscription?.cancel();
      _userPostsSubscription = _postService.getUserPosts(userId).listen(
        (posts) {
          _userPosts = posts;
          notifyListeners();
        },
        onError: (error) {
          _setError('Failed to load user posts: $error');
        },
      );
    } catch (e) {
      _setError('Failed to load user posts: $e');
    }
  }

  // Create a new post
  Future<bool> createPost({
    required String title,
    required String description,
    required String authorId,
    required String authorName,
    required DateTime scheduledTime,
    required List<String> genderPreferences,
    String? location,
    int maxParticipants = 10,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final now = DateTime.now();
      final isNow = scheduledTime.difference(now).inMinutes.abs() < 1;
      
      final post = Post(
        id: '', // Will be set by Firestore
        title: title,
        description: description,
        authorId: authorId,
        authorName: authorName,
        createdAt: DateTime.now(),
        scheduledTime: scheduledTime,
        status: isNow ? PostStatus.ongoing : PostStatus.upcoming,
        participantIds: [authorId], // Author is automatically a participant
        location: location,
        maxParticipants: maxParticipants,
        genderPreferences: genderPreferences,
      );

      await _postService.createPost(post);
      return true;
    } catch (e) {
      _setError('Failed to create post: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Join a post
  Future<bool> joinPost(String postId, String userId) async {
    try {
      await _postService.joinPost(postId, userId);
      return true;
    } catch (e) {
      _setError('Failed to join post: $e');
      return false;
    }
  }

  // Leave a post
  Future<bool> leavePost(String postId, String userId) async {
    try {
      await _postService.leavePost(postId, userId);
      return true;
    } catch (e) {
      _setError('Failed to leave post: $e');
      return false;
    }
  }

  // Update a post
  Future<bool> updatePost(Post post) async {
    _setLoading(true);
    _clearError();

    try {
      await _postService.updatePost(post);
      return true;
    } catch (e) {
      _setError('Failed to update post: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Delete a post
  Future<bool> deletePost(String postId) async {
    _setLoading(true);
    _clearError();

    try {
      await _postService.deletePost(postId);
      return true;
    } catch (e) {
      _setError('Failed to delete post: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Get posts filtered by gender preferences
  List<Post> getPostsForUser(List<String> userGenders) {
    return _posts.where((post) {
      // If post accepts "Anyone", it matches any user
      if (post.genderPreferences.contains('Anyone')) {
        return true;
      }
      
      // Check if user's gender matches any of the post's preferences
      return userGenders.any((userGender) => 
          post.genderPreferences.contains(userGender));
    }).toList();
  }

  // Get upcoming posts for user
  List<Post> getUpcomingPostsForUser(List<String> userGenders) {
    return _upcomingPosts.where((post) {
      if (post.genderPreferences.contains('Anyone')) {
        return true;
      }
      return userGenders.any((userGender) => 
          post.genderPreferences.contains(userGender));
    }).toList();
  }

  // Get ongoing posts for user
  List<Post> getOngoingPostsForUser(List<String> userGenders) {
    return _ongoingPosts.where((post) {
      if (post.genderPreferences.contains('Anyone')) {
        return true;
      }
      return userGenders.any((userGender) => 
          post.genderPreferences.contains(userGender));
    }).toList();
  }

  // Search posts
  Stream<List<Post>> searchPosts(String query) {
    return _postService.searchPosts(query);
  }

  // Update post statuses (call periodically)
  Future<void> updatePostStatuses() async {
    try {
      await _postService.updatePostStatuses();
    } catch (e) {
      debugPrint('Failed to update post statuses: $e');
    }
  }

  // Check if user can join a post
  bool canUserJoinPost(Post post, String userId) {
    // Check if already joined
    if (post.participantIds.contains(userId)) {
      return false;
    }
    
    // Check if post is full
    if (post.participantIds.length >= post.maxParticipants) {
      return false;
    }
    
    // Check if post is completed
    if (post.dynamicStatus == PostStatus.completed) {
      return false;
    }
    
    return true;
  }

  // Get post by ID from current posts
  Post? getPostById(String postId) {
    try {
      return _posts.firstWhere((post) => post.id == postId);
    } catch (e) {
      return null;
    }
  }

  // Private methods
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    if (_error != null) {
      _error = null;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _postsSubscription?.cancel();
    _upcomingSubscription?.cancel();
    _ongoingSubscription?.cancel();
    _userPostsSubscription?.cancel();
    super.dispose();
  }
}