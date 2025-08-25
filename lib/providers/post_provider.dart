import 'package:flutter/foundation.dart';
import '../models/post_model.dart';
import '../services/post_service.dart';
import 'dart:async';

class PostProvider with ChangeNotifier {
  final PostService _postService = PostService();
  
  List<Post> _posts = [];
  List<Post> _allPosts = []; // Includes locked posts
  List<Post> _upcomingPosts = [];
  List<Post> _ongoingPosts = [];
  List<Post> _userPosts = [];
  
  bool _isLoading = false;
  String? _error;
  String? _lastCreatedPostId;
  
  StreamSubscription<List<Post>>? _postsSubscription;
  StreamSubscription<List<Post>>? _allPostsSubscription;
  StreamSubscription<List<Post>>? _upcomingSubscription;
  StreamSubscription<List<Post>>? _ongoingSubscription;
  StreamSubscription<List<Post>>? _userPostsSubscription;
  Timer? _refreshTimer;

  // Getters
  List<Post> get posts => _posts;
  List<Post> get allPosts => _allPosts; // Includes locked posts
  List<Post> get upcomingPosts => _upcomingPosts;
  List<Post> get ongoingPosts => _ongoingPosts;
  List<Post> get userPosts => _userPosts;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get lastCreatedPostId => _lastCreatedPostId;

  // Initialize and start listening to posts
  Future<void> initialize() async {
    _setLoading(true);
    _clearError();
    
    try {
      // Subscribe to all posts (excluding locked)
      _postsSubscription = _postService.getPosts().listen(
        (posts) {
          _posts = posts;
          notifyListeners();
        },
        onError: (error) {
          _setError('Failed to load posts: $error');
        },
      );

      // Subscribe to all posts including locked ones
      _allPostsSubscription = _postService.getAllPosts().listen(
        (posts) {
          _allPosts = posts;
          notifyListeners();
        },
        onError: (error) {
          _setError('Failed to load all posts: $error');
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

      // Start periodic refresh timer (every 30 seconds)
      _startRefreshTimer();

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

      _lastCreatedPostId = await _postService.createPost(post);
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

  // Delete a post with hybrid feedback approach
  Future<bool> deletePostWithFeedback(String postId, String authorId, {bool? authorDidMeetup, String? authorAdditionalFeedback}) async {
    _setLoading(true);
    _clearError();

    try {
      await _postService.deletePostWithFeedback(postId, authorId, authorDidMeetup: authorDidMeetup, authorAdditionalFeedback: authorAdditionalFeedback);
      return true;
    } catch (e) {
      _setError('Failed to delete post with feedback: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Lock a post (hide from discovery)
  Future<bool> lockPost(String postId) async {
    try {
      await _postService.lockPost(postId);
      return true;
    } catch (e) {
      _setError('Failed to lock post: $e');
      return false;
    }
  }

  // Unlock a post (make visible for discovery)
  Future<bool> unlockPost(String postId) async {
    try {
      await _postService.unlockPost(postId);
      return true;
    } catch (e) {
      _setError('Failed to unlock post: $e');
      return false;
    }
  }

  // Helper method to check if user can see a post based on gender
  bool _canUserSeePost(Post post, String? userGender) {
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

  // Get posts filtered by user's gender preferences
  List<Post> getPostsForUser(String? userGender) {
    return _posts.where((post) => _canUserSeePost(post, userGender)).toList();
  }

  // Get upcoming posts for user
  List<Post> getUpcomingPostsForUser(String? userGender) {
    return _upcomingPosts.where((post) => _canUserSeePost(post, userGender)).toList();
  }

  // Get ongoing posts for user
  List<Post> getOngoingPostsForUser(String? userGender) {
    return _ongoingPosts.where((post) => _canUserSeePost(post, userGender)).toList();
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

  // Start refresh timer to update UI every 30 seconds
  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      // Just notify listeners to refresh the UI with dynamic status calculations
      notifyListeners();
      
      // Optionally update database statuses every 5 minutes (10 timer cycles)
      if (timer.tick % 10 == 0) {
        updatePostStatuses();
      }
    });
  }

  // Stop refresh timer
  void _stopRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
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
    _allPostsSubscription?.cancel();
    _upcomingSubscription?.cancel();
    _ongoingSubscription?.cancel();
    _userPostsSubscription?.cancel();
    _stopRefreshTimer();
    super.dispose();
  }
}