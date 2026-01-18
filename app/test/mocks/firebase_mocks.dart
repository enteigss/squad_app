import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:google_sign_in_mocks/google_sign_in_mocks.dart';

/// Firebase mock instances for testing services
///
/// Use these when testing your SERVICE classes (AuthService, PostService, etc.)
/// These provide fake Firebase instances that work in memory.
///
/// Example:
/// ```dart
/// test('PostService can create post', () {
///   final fakeFirestore = FirebaseMocks.fakeFirestore;
///   final postService = PostService(firestore: fakeFirestore);
///
///   await postService.createPost(testPost);
///
///   // Data is stored in fake Firestore, not real Firebase
/// });
/// ```
class FirebaseMocks {
  /// Creates a fresh FakeFirebaseFirestore instance
  /// This acts like real Firestore but stores everything in memory
  static FakeFirebaseFirestore get fakeFirestore => FakeFirebaseFirestore();

  /// Creates a MockFirebaseAuth with no signed-in user
  static MockFirebaseAuth get mockAuth => MockFirebaseAuth();

  /// Creates a MockFirebaseAuth with a signed-in user
  static MockFirebaseAuth mockAuthWithUser({
    required String uid,
    String? email,
    String? displayName,
    String? photoUrl,
    bool isEmailVerified = true,
  }) {
    final user = MockUser(
      uid: uid,
      email: email,
      displayName: displayName,
      photoURL: photoUrl,
      isEmailVerified: isEmailVerified,
    );
    return MockFirebaseAuth(mockUser: user, signedIn: true);
  }

  /// Creates a MockGoogleSignIn for testing Google Sign-In flows
  static MockGoogleSignIn get mockGoogleSignIn => MockGoogleSignIn();

  /// Creates a FakeFirebaseFirestore pre-populated with test data
  ///
  /// Example:
  /// ```dart
  /// final firestore = await FirebaseMocks.firestoreWithData(
  ///   collections: {
  ///     'users': [testUser.toMap()],
  ///     'posts': [testPost.toMap()],
  ///   },
  /// );
  /// ```
  static Future<FakeFirebaseFirestore> firestoreWithData({
    Map<String, List<Map<String, dynamic>>>? collections,
  }) async {
    final firestore = FakeFirebaseFirestore();

    if (collections != null) {
      for (final entry in collections.entries) {
        final collectionName = entry.key;
        final documents = entry.value;

        for (final doc in documents) {
          final docId = doc['id'] as String?;
          if (docId != null) {
            await firestore.collection(collectionName).doc(docId).set(doc);
          } else {
            await firestore.collection(collectionName).add(doc);
          }
        }
      }
    }

    return firestore;
  }
}
