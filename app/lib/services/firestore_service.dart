import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore;

  FirestoreService({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> updateUserProfile({
    required String userId,
    String? displayName,
    String? photoUrl,
    String? bio,
    int? age,
    String? location,
    List<String>? interests,
  }) async {
    final Map<String, dynamic> updateData = {
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (displayName != null) updateData['displayName'] = displayName;
    if (photoUrl != null) updateData['photoUrl'] = photoUrl;
    if (bio != null) updateData['bio'] = bio;
    if (age != null) updateData['age'] = age;
    if (location != null) updateData['location'] = location;
    if (interests != null) updateData['interests'] = interests;

    await _firestore
        .collection('users')
        .doc(userId)
        .set(updateData, SetOptions(merge: true));
  }

  Future<List<UserModel>> searchUsers(String query) async {
    try {
      final QuerySnapshot result = await _firestore
          .collection('users')
          .where('username', isGreaterThanOrEqualTo: query)
          .where('username', isLessThan: '${query}z')
          .limit(10)
          .get();

      return result.docs
          .map((doc) => UserModel.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<UserModel?> getUser(String userId) async {
    try {
      final DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(userId)
          .get();

      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get user: $e');
    }
  }

  // Remove a member from a post
  Future<void> removeMemberFromPost(String postId, String userId) async {
    try {
      await _firestore.collection('posts').doc(postId).update({
        'participantIds': FieldValue.arrayRemove([userId]),
      });
    } catch (e) {
      throw Exception('Failed to remove member from post: $e');
    }
  }
}
