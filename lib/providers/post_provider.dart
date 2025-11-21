import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/post_model.dart';
import '../models/user_model.dart';
import '../services/post_service.dart';
import '../services/block_service.dart';
import 'dart:async';

class PostProvider with ChangeNotifier {
  final PostService _postService = PostService();
  final BlockService _blockService = BlockService();

  List<Post> _posts = [];
  List<Post> _allPosts = []; // Includes locked posts
  List<Post> _upcomingPosts = [];
  List<Post> _ongoingPosts = [];
  List<Post> _userPosts = [];

  List<Post> _filteredPosts = [];
  List<Post> _filteredAllPosts = [];
  List<Post> _filteredUpcomingPosts = [];
  List<Post> _filteredOngoingPosts = [];
  UserModel? _currentUser;

  // Direct Firestore user listener
  StreamSubscription<DocumentSnapshot>? _userSubscription;

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
  List<Post> get posts {
    debugPrint(
      '📱 UI ACCESS DEBUG: UI requesting posts - returning ${_filteredPosts.length} filtered posts',
    );
    if (_filteredPosts.isNotEmpty) {
      debugPrint(
        '📱 UI ACCESS DEBUG: Posts being shown: ${_filteredPosts.map((p) => '${p.id} by ${p.authorName}').join(', ')}',
      );
    }
    return _filteredPosts;
  }

  List<Post> get allPosts {
    debugPrint(
      '📱 UI ACCESS DEBUG: UI requesting allPosts - returning ${_filteredAllPosts.length} filtered all posts',
    );
    if (_filteredAllPosts.isNotEmpty) {
      debugPrint(
        '📱 UI ACCESS DEBUG: All posts being shown: ${_filteredAllPosts.map((p) => '${p.id} by ${p.authorName}').join(', ')}',
      );
    }
    return _filteredAllPosts;
  }

  List<Post> get upcomingPosts {
    debugPrint(
      '📱 UI ACCESS DEBUG: UI requesting upcomingPosts - returning ${_filteredUpcomingPosts.length} filtered upcoming posts',
    );
    if (_filteredUpcomingPosts.isNotEmpty) {
      debugPrint(
        '📱 UI ACCESS DEBUG: Upcoming posts being shown: ${_filteredUpcomingPosts.map((p) => '${p.id} by ${p.authorName}').join(', ')}',
      );
    }
    return _filteredUpcomingPosts;
  }

  List<Post> get ongoingPosts {
    debugPrint(
      '📱 UI ACCESS DEBUG: UI requesting ongoingPosts - returning ${_filteredOngoingPosts.length} filtered ongoing posts',
    );
    if (_filteredOngoingPosts.isNotEmpty) {
      debugPrint(
        '📱 UI ACCESS DEBUG: Ongoing posts being shown: ${_filteredOngoingPosts.map((p) => '${p.id} by ${p.authorName}').join(', ')}',
      );
    }
    return _filteredOngoingPosts;
  }

  List<Post> get userPosts => _userPosts; // User posts are not filtered
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get lastCreatedPostId => _lastCreatedPostId;

  // Initialize with user ID and listen to Firestore directly
  void initializeForUser(String userId) {
    debugPrint(
      '🔗 PostProvider: Initializing for user $userId with Firestore listener',
    );

    // Cancel previous subscription if any
    _userSubscription?.cancel();

    // Listen directly to user document in Firestore
    _userSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.exists) {
              final newUser = UserModel.fromMap(snapshot.data()!);

              debugPrint(
                '🔄 PostProvider: User document updated from Firestore',
              );
              debugPrint(
                '🔄 PostProvider: User: ${newUser.username} (${newUser.id})',
              );
              debugPrint(
                '🔄 PostProvider: Blocked IDs: ${newUser.blockedUserIds}',
              );
              debugPrint(
                '🔄 PostProvider: Blocked by IDs: ${newUser.blockedByUserIds}',
              );
              debugPrint('🔄 PostProvider: Gender: ${newUser.gender}');

              // Check if relevant data changed
              final blockingChanged =
                  _currentUser == null ||
                  !listEquals(
                    newUser.blockedUserIds,
                    _currentUser!.blockedUserIds,
                  ) ||
                  !listEquals(
                    newUser.blockedByUserIds,
                    _currentUser!.blockedByUserIds,
                  );
              final genderChanged =
                  _currentUser == null ||
                  newUser.gender != _currentUser!.gender;

              if (blockingChanged || genderChanged) {
                debugPrint(
                  '✅ PostProvider: Relevant changes detected (blocking: $blockingChanged, gender: $genderChanged)',
                );
                _currentUser = newUser;
                _filterPosts();
                notifyListeners();
              } else {
                debugPrint(
                  '⏭️ PostProvider: No relevant changes, keeping current filters',
                );
                _currentUser = newUser; // Still update reference for other data
              }
            }
          },
          onError: (error) {
            debugPrint(
              '❌ PostProvider: Error listening to user document: $error',
            );
            _setError('Failed to sync user data: $error');
          },
        );

    // Also initialize post streams if not already done
    initialize();
  }

  // Initialize and start listening to posts
  Future<void> initialize() async {
    _setLoading(true);
    _clearError();

    try {
      // Subscribe to all posts (excluding locked)
      _postsSubscription = _postService.getPosts().listen(
        (posts) {
          debugPrint(
            '🔄 POST LOAD DEBUG: Received ${posts.length} posts from database',
          );
          if (posts.isNotEmpty) {
            debugPrint(
              '🔄 POST LOAD DEBUG: Sample post authors: ${posts.take(3).map((p) => '${p.authorName} (${p.authorId})').join(', ')}',
            );
          }
          _posts = posts;
          _filterPosts();
          notifyListeners();
        },
        onError: (error) {
          _setError('Failed to load posts: $error');
        },
      );

      // Subscribe to all posts including locked ones
      _allPostsSubscription = _postService.getAllPosts().listen(
        (posts) {
          debugPrint(
            '🔄 ALL POSTS DEBUG: Received ${posts.length} all posts (including locked) from database',
          );
          if (posts.isNotEmpty) {
            debugPrint(
              '🔄 ALL POSTS DEBUG: Sample post authors: ${posts.take(3).map((p) => '${p.authorName} (${p.authorId})').join(', ')}',
            );
          }
          _allPosts = posts;
          _filterPosts();
          notifyListeners();
        },
        onError: (error) {
          _setError('Failed to load all posts: $error');
        },
      );

      // Subscribe to upcoming posts
      _upcomingSubscription = _postService.getUpcomingPosts().listen((posts) {
        debugPrint(
          '📡 DB DEBUG: Received ${posts.length} upcoming posts from database',
        );
        if (posts.isNotEmpty) {
          debugPrint(
            '📡 DB DEBUG: Sample upcoming post: "${posts.first.id}" - Gender prefs: ${posts.first.genderPreferences}',
          );
          debugPrint(
            '📡 DB DEBUG: Upcoming post authors: ${posts.take(3).map((p) => '${p.authorName} (${p.authorId})').join(', ')}',
          );
        }
        _upcomingPosts = posts;
        _filterPosts();
        notifyListeners();
      });

      // Subscribe to ongoing posts
      _ongoingSubscription = _postService.getOngoingPosts().listen((posts) {
        debugPrint(
          '📡 DB DEBUG: Received ${posts.length} ongoing posts from database',
        );
        if (posts.isNotEmpty) {
          debugPrint(
            '📡 DB DEBUG: Sample ongoing post: "${posts.first.id}" - Gender prefs: ${posts.first.genderPreferences}',
          );
          debugPrint(
            '📡 DB DEBUG: Ongoing post authors: ${posts.take(3).map((p) => '${p.authorName} (${p.authorId})').join(', ')}',
          );
        }
        _ongoingPosts = posts;
        _filterPosts();
        notifyListeners();
      });

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
      _userPostsSubscription = _postService
          .getUserPosts(userId)
          .listen(
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
    required PostType type,
    required String authorId,
    required String authorName,
    required List<String> genderPreferences,
    String? description,
    DateTime? scheduledTime,
    Activity? activity,
    String? customActivity,
    String? location,
    String? locationTo,
    int? maxParticipants,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      final now = DateTime.now();
      final isNow = scheduledTime == null || scheduledTime.difference(now).inMinutes.abs() < 1;

      final post = Post(
        id: '', // Will be set by Firestore
        type: type,
        activity: activity,
        customActivity: customActivity,
        description: description,
        authorId: authorId,
        authorName: authorName,
        createdAt: DateTime.now(),
        scheduledTime: scheduledTime,
        status: isNow ? PostStatus.ongoing : PostStatus.upcoming,
        participantIds: [authorId], // Author is automatically a participant
        location: location,
        locationTo: locationTo,
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

  // Check if author needs to provide feedback before deletion
  Future<bool> doesAuthorNeedFeedbackForDeletion(
    String postId,
    String authorId,
  ) async {
    try {
      return await _postService.doesAuthorNeedFeedbackForDeletion(
        postId,
        authorId,
      );
    } catch (e) {
      _setError('Failed to check feedback status: $e');
      return true; // Default to showing dialog if uncertain
    }
  }

  // Delete a post with feedback from author
  Future<bool> deletePostWithFeedback(
    String postId,
    String authorId, {
    bool? authorDidMeetup,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      await _postService.deletePostWithFeedback(
        postId,
        authorId,
        authorDidMeetup: authorDidMeetup,
      );
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
    debugPrint('🔍 GENDER DEBUG: Checking if user can see post "${post.id}"');
    debugPrint('🔍 GENDER DEBUG: User gender: $userGender');
    debugPrint(
      '🔍 GENDER DEBUG: Post gender preferences: ${post.genderPreferences}',
    );

    // If user hasn't specified gender, they can only see posts that include ALL three options
    if (userGender == null || userGender == 'prefer_not_to_say') {
      final canSee =
          post.genderPreferences.contains('Men') &&
          post.genderPreferences.contains('Women') &&
          post.genderPreferences.contains('Non-binary');
      debugPrint(
        '🔍 GENDER DEBUG: User has no gender specified, can see post: $canSee',
      );
      return canSee;
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
        // For any other gender identities, map to 'Other'
        expectedPreference = 'Other';
        break;
    }

    debugPrint(
      '🔍 GENDER DEBUG: Expected preference for user: $expectedPreference',
    );

    // Check if post's gender preferences include the user's gender
    final canSee = post.genderPreferences.contains(expectedPreference);
    debugPrint('🔍 GENDER DEBUG: Can user see post: $canSee');

    return canSee;
  }

  // Get posts filtered by both blocks and user's gender preferences
  List<Post> getPostsForUser(String? userGender) {
    debugPrint('✅ FIXED DEBUG: getPostsForUser now using block-filtered posts');
    debugPrint(
      '✅ FIXED DEBUG: Using filtered posts: ${_filteredPosts.length} (block filtering applied)',
    );
    final result = _filteredPosts
        .where((post) => _canUserSeePost(post, userGender))
        .toList();
    debugPrint(
      '✅ FIXED DEBUG: Posts after gender filter: ${result.map((p) => '${p.id} by ${p.authorName}').join(', ')}',
    );
    return result;
  }

  // Get upcoming posts filtered by both blocks and user's gender preferences
  List<Post> getUpcomingPostsForUser(String? userGender) {
    debugPrint(
      '✅ FIXED DEBUG: getUpcomingPostsForUser now using block-filtered posts',
    );
    debugPrint(
      '✅ FIXED DEBUG: Using filtered upcoming posts: ${_filteredUpcomingPosts.length} (block filtering applied)',
    );

    final filtered = _filteredUpcomingPosts
        .where((post) => _canUserSeePost(post, userGender))
        .toList();
    debugPrint(
      '✅ FIXED DEBUG: Posts after gender filter: ${filtered.map((p) => '${p.id} by ${p.authorName}').join(', ')}',
    );

    if (filtered.isEmpty && _filteredUpcomingPosts.isNotEmpty) {
      debugPrint(
        '⚠️ PROVIDER DEBUG: All upcoming posts filtered out by gender preferences!',
      );
      debugPrint(
        '🔍 PROVIDER DEBUG: Sample post gender prefs: ${_filteredUpcomingPosts.first.genderPreferences}',
      );
    }

    return filtered;
  }

  // Get ongoing posts filtered by both blocks and user's gender preferences
  List<Post> getOngoingPostsForUser(String? userGender) {
    debugPrint(
      '✅ FIXED DEBUG: getOngoingPostsForUser now using block-filtered posts',
    );
    debugPrint(
      '✅ FIXED DEBUG: Using filtered ongoing posts: ${_filteredOngoingPosts.length} (block filtering applied)',
    );

    final filtered = _filteredOngoingPosts
        .where((post) => _canUserSeePost(post, userGender))
        .toList();
    debugPrint(
      '✅ FIXED DEBUG: Posts after gender filter: ${filtered.map((p) => '${p.id} by ${p.authorName}').join(', ')}',
    );

    if (filtered.isEmpty && _filteredOngoingPosts.isNotEmpty) {
      debugPrint(
        '⚠️ PROVIDER DEBUG: All ongoing posts filtered out by gender preferences!',
      );
      debugPrint(
        '🔍 PROVIDER DEBUG: Sample post gender prefs: ${_filteredOngoingPosts.first.genderPreferences}',
      );
    }

    return filtered;
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

  // Start refresh timer to update database statuses every 5 minutes
  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      // Update database statuses (triggers Firestore stream updates)
      // UI will update via Firestore stream listeners, not manual notifyListeners()
      updatePostStatuses();
    });
  }

  // Stop refresh timer
  void _stopRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  // Helper method to check gender compatibility
  bool _isUserGenderCompatible(Post post, String? userGender) {
    // If user hasn't specified gender, they can only join posts that include ALL three options
    if (userGender == null || userGender == 'prefer_not_to_say') {
      return post.genderPreferences.contains('Men') &&
          post.genderPreferences.contains('Women') &&
          post.genderPreferences.contains('Non-binary');
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

  // Check if user can join a post
  bool canUserJoinPost(Post post, String userId, {String? userGender}) {
    // Check if already joined
    if (post.participantIds.contains(userId)) {
      return false;
    }

    // Check if post is full
    // Use the set limit if available, otherwise use the hard limit of 100
    final effectiveLimit = post.maxParticipants ?? 100;
    if (post.participantIds.length >= effectiveLimit) {
      return false;
    }

    // Check if post is completed
    if (post.dynamicStatus == PostStatus.completed) {
      return false;
    }

    // Check gender compatibility
    if (!_isUserGenderCompatible(post, userGender)) {
      return false;
    }

    return true;
  }

  // Get post by ID from current posts
  Post? getPostById(String postId) {
    try {
      // First try to find in allPosts (includes locked posts that user is part of)
      return _allPosts.firstWhere((post) => post.id == postId);
    } catch (e) {
      // Fallback to regular posts if not found
      try {
        return _posts.firstWhere((post) => post.id == postId);
      } catch (e) {
        return null;
      }
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

  // Set current user for blocking functionality
  // DEPRECATED: No longer needed with Firestore listener
  @Deprecated('Use initializeForUser() with userId instead')
  void setCurrentUser(UserModel user) {
    debugPrint(
      '⚠️ DEPRECATED: setCurrentUser called - using initializeForUser() is recommended',
    );
    debugPrint('👤 Setting current user: ${user.username} (${user.id})');
    _currentUser = user;
    _filterPosts();
    notifyListeners();
  }

  // Filter posts based on blocked users
  void _filterPosts() {
    debugPrint('🚫 BLOCK FILTER DEBUG: Starting post filtering...');
    debugPrint(
      '🚫 BLOCK FILTER DEBUG: Current user null check: ${_currentUser == null}',
    );

    if (_currentUser == null) {
      debugPrint(
        '🚫 BLOCK FILTER DEBUG: No current user set, showing all posts unfiltered',
      );
      _filteredPosts = _posts;
      _filteredAllPosts = _allPosts;
      _filteredUpcomingPosts = _upcomingPosts;
      _filteredOngoingPosts = _ongoingPosts;
      return;
    }

    debugPrint(
      '🚫 BLOCK FILTER DEBUG: Current user: ${_currentUser!.username} (${_currentUser!.id})',
    );
    debugPrint(
      '🚫 BLOCK FILTER DEBUG: User blocked IDs: ${_currentUser!.blockedUserIds}',
    );
    debugPrint(
      '🚫 BLOCK FILTER DEBUG: User blocked by IDs: ${_currentUser!.blockedByUserIds}',
    );
    debugPrint(
      '🚫 BLOCK FILTER DEBUG: Blocked list length: ${_currentUser!.blockedUserIds.length}',
    );

    // Filter regular posts
    final originalPostsCount = _posts.length;
    _filteredPosts = _posts.where((post) {
      // Hide hangouts from users you've blocked
      final shouldHideFromUserIBlocked = _blockService.shouldFilterContent(
        post.authorId,
        _currentUser!.blockedUserIds,
        _currentUser!.blockedByUserIds,
      );

      // Hide hangouts where the host has blocked you
      final shouldHideFromBlockedUser = _blockService
          .shouldHideHangoutFromBlocked(
            post.authorId,
            _currentUser!.blockedUserIds,
            _currentUser!.blockedByUserIds,
          );

      final shouldFilter =
          shouldHideFromUserIBlocked || shouldHideFromBlockedUser;

      if (shouldFilter) {
        debugPrint(
          '🚫 BLOCK FILTER DEBUG: Filtering out post "${post.id}" by ${post.authorName} (${post.authorId})',
        );
      }
      return !shouldFilter;
    }).toList();
    debugPrint(
      '🚫 BLOCK FILTER DEBUG: Regular posts: ${originalPostsCount} → ${_filteredPosts.length} (filtered out ${originalPostsCount - _filteredPosts.length})',
    );

    // Filter all posts
    final originalAllPostsCount = _allPosts.length;
    _filteredAllPosts = _allPosts.where((post) {
      // Hide hangouts from users you've blocked
      final shouldHideFromUserIBlocked = _blockService.shouldFilterContent(
        post.authorId,
        _currentUser!.blockedUserIds,
        _currentUser!.blockedByUserIds,
      );

      // Hide hangouts where the host has blocked you
      final shouldHideFromBlockedUser = _blockService
          .shouldHideHangoutFromBlocked(
            post.authorId,
            _currentUser!.blockedUserIds,
            _currentUser!.blockedByUserIds,
          );

      final shouldFilter =
          shouldHideFromUserIBlocked || shouldHideFromBlockedUser;

      if (shouldFilter) {
        debugPrint(
          '🚫 BLOCK FILTER DEBUG: Filtering out all post "${post.id}" by ${post.authorName} (${post.authorId})',
        );
      }
      return !shouldFilter;
    }).toList();
    debugPrint(
      '🚫 BLOCK FILTER DEBUG: All posts: ${originalAllPostsCount} → ${_filteredAllPosts.length} (filtered out ${originalAllPostsCount - _filteredAllPosts.length})',
    );

    // Filter upcoming posts
    final originalUpcomingCount = _upcomingPosts.length;
    _filteredUpcomingPosts = _upcomingPosts.where((post) {
      // Hide hangouts from users you've blocked
      final shouldHideFromUserIBlocked = _blockService.shouldFilterContent(
        post.authorId,
        _currentUser!.blockedUserIds,
        _currentUser!.blockedByUserIds,
      );

      // Hide hangouts where the host has blocked you
      final shouldHideFromBlockedUser = _blockService
          .shouldHideHangoutFromBlocked(
            post.authorId,
            _currentUser!.blockedUserIds,
            _currentUser!.blockedByUserIds,
          );

      final shouldFilter =
          shouldHideFromUserIBlocked || shouldHideFromBlockedUser;

      if (shouldFilter) {
        debugPrint(
          '🚫 BLOCK FILTER DEBUG: Filtering out upcoming post "${post.id}" by ${post.authorName} (${post.authorId})',
        );
      }
      return !shouldFilter;
    }).toList();
    debugPrint(
      '🚫 BLOCK FILTER DEBUG: Upcoming posts: ${originalUpcomingCount} → ${_filteredUpcomingPosts.length} (filtered out ${originalUpcomingCount - _filteredUpcomingPosts.length})',
    );

    // Filter ongoing posts
    final originalOngoingCount = _ongoingPosts.length;
    debugPrint('🔍 DETAILED DEBUG: Starting ongoing posts filtering...');
    debugPrint(
      '🔍 DETAILED DEBUG: Original ongoing posts: ${_ongoingPosts.map((p) => '${p.id} by ${p.authorName} (${p.authorId})').join(', ')}',
    );

    _filteredOngoingPosts = _ongoingPosts.where((post) {
      // Hide hangouts from users you've blocked
      final shouldHideFromUserIBlocked = _blockService.shouldFilterContent(
        post.authorId,
        _currentUser!.blockedUserIds,
        _currentUser!.blockedByUserIds,
      );

      // Hide hangouts where the host has blocked you
      final shouldHideFromBlockedUser = _blockService
          .shouldHideHangoutFromBlocked(
            post.authorId,
            _currentUser!.blockedUserIds,
            _currentUser!.blockedByUserIds,
          );

      final shouldFilter =
          shouldHideFromUserIBlocked || shouldHideFromBlockedUser;

      debugPrint(
        '🔍 DETAILED DEBUG: Post "${post.id}" by ${post.authorName} (${post.authorId}) - shouldFilter: $shouldFilter',
      );
      debugPrint(
        '🔍 DETAILED DEBUG: - shouldHideFromUserIBlocked: $shouldHideFromUserIBlocked',
      );
      debugPrint(
        '🔍 DETAILED DEBUG: - shouldHideFromBlockedUser: $shouldHideFromBlockedUser',
      );
      debugPrint(
        '🔍 DETAILED DEBUG: - blockedUserIds contains ${post.authorId}: ${_currentUser!.blockedUserIds.contains(post.authorId)}',
      );
      debugPrint(
        '🔍 DETAILED DEBUG: - blockedByUserIds contains ${post.authorId}: ${_currentUser!.blockedByUserIds.contains(post.authorId)}',
      );

      if (shouldFilter) {
        debugPrint(
          '🚫 BLOCK FILTER DEBUG: Filtering out ongoing post "${post.id}" by ${post.authorName} (${post.authorId})',
        );
      } else {
        debugPrint(
          '✅ BLOCK FILTER DEBUG: Keeping ongoing post "${post.id}" by ${post.authorName} (${post.authorId})',
        );
      }
      return !shouldFilter;
    }).toList();
    debugPrint(
      '🚫 BLOCK FILTER DEBUG: Ongoing posts: ${originalOngoingCount} → ${_filteredOngoingPosts.length} (filtered out ${originalOngoingCount - _filteredOngoingPosts.length})',
    );

    // Log final filtered results for visibility in feed
    if (_filteredPosts.isNotEmpty ||
        _filteredUpcomingPosts.isNotEmpty ||
        _filteredOngoingPosts.isNotEmpty) {
      debugPrint('🚫 BLOCK FILTER DEBUG: === FINAL VISIBLE POSTS IN FEED ===');
      if (_filteredPosts.isNotEmpty) {
        debugPrint(
          '🚫 BLOCK FILTER DEBUG: Regular posts visible: ${_filteredPosts.map((p) => '${p.id} by ${p.authorName}').join(', ')}',
        );
      }
      if (_filteredUpcomingPosts.isNotEmpty) {
        debugPrint(
          '🚫 BLOCK FILTER DEBUG: Upcoming posts visible: ${_filteredUpcomingPosts.map((p) => '${p.id} by ${p.authorName}').join(', ')}',
        );
      }
      if (_filteredOngoingPosts.isNotEmpty) {
        debugPrint(
          '🚫 BLOCK FILTER DEBUG: Ongoing posts visible: ${_filteredOngoingPosts.map((p) => '${p.id} by ${p.authorName}').join(', ')}',
        );
      }
    } else {
      debugPrint(
        '🚫 BLOCK FILTER DEBUG: No posts visible in feed after filtering',
      );
    }
  }

  // Clean up when user logs out (without disposing the provider)
  void cleanup() {
    debugPrint('🧹 PostProvider: Cleaning up subscriptions for logout');
    _postsSubscription?.cancel();
    _allPostsSubscription?.cancel();
    _upcomingSubscription?.cancel();
    _ongoingSubscription?.cancel();
    _userPostsSubscription?.cancel();
    _userSubscription?.cancel();
    _stopRefreshTimer();

    // Clear cached data
    _posts = [];
    _allPosts = [];
    _upcomingPosts = [];
    _ongoingPosts = [];
    _userPosts = [];
    _filteredPosts = [];
    _filteredAllPosts = [];
    _filteredUpcomingPosts = [];
    _filteredOngoingPosts = [];
    _currentUser = null;
    _isLoading = false;
    _error = null;
  }

  @override
  void dispose() {
    cleanup();
    super.dispose();
  }
}
