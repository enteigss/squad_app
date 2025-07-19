import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  AuthService() {
    _auth.authStateChanges().listen((User? user) {
      if (user == null) {
        print('User is currently signed out!');
        // Navigate to login screen?
      } else {
        print('User is signed in! UID: ${user.uid}');
        // navigate to main app screen?
      }
    });
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserModel?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        await _updateUserOnlineStatus(result.user!.uid, true);
        return await getUserData(result.user!.uid);
      }
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        print('NO user found for that email.');
      } else if (e.code == 'wrong-password') {
        print('Wrong password provided for that user.');
      }
      rethrow;
    } catch (e) {
      print(e);
      rethrow;
    }
  }

  Future<UserModel?> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null) {
        final UserModel newUser = UserModel(
          id: result.user!.uid,
          email: email,
          username: email.split('@')[0],
          displayName: null,
          createdAt: DateTime.now(),
          isOnline: true,
          hasCreatedProfile: false,
        );

        final userData = {
          'id': result.user!.uid,
          'email': email,
          'username': email.split('@')[0],
          'displayName': null,
          'createdAt': DateTime.now(),
          'isOnline': true,
          'hasCreatedProfile': false,
        };

        await _firestore
            .collection('users')
            .doc(result.user!.uid)
            .set(userData);

        return newUser;
      }
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        print('The password provided is too weak.');
      } else if (e.code == 'email-already-in-use') {
        print('The account already exists for that email.');
      }
      rethrow;
    } catch (e) {
      print("SignUp failed:");
      print(e);
      rethrow;
    }
  }

  Future<UserModel?> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn.instance;
      googleSignIn.initialize(
        serverClientId:
            "555170207131-7svrdoua7njct4p8pebdrlfibshdbkih.apps.googleusercontent.com",
      );

      // Check if authenticate() is supported
      if (GoogleSignIn.instance.supportsAuthenticate()) {
        final GoogleSignInAccount? googleUser = await googleSignIn
            .authenticate();

        if (googleUser == null) {
          return null; // User cancelled
        }

        // Get authentication details
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        // Create Firebase credential and sign in
        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );

        final UserCredential result = await _auth.signInWithCredential(
          credential,
        );

        if (result.user != null) {
          print('🔐 Google sign-in successful for user: ${result.user!.uid}');
          
          // Check if user document exists in Firestore
          final existingUser = await getUserData(result.user!.uid);
          print('🔍 Existing user in Firestore: ${existingUser?.toMap()}');

          if (existingUser == null) {
            print('➕ Creating new user document in Firestore');
            
            // Create new user document for Google sign-in
            final UserModel newUser = UserModel(
              id: result.user!.uid,
              email: result.user!.email ?? '',
              username: result.user!.email?.split('@')[0] ?? 'user',
              displayName: result.user!.displayName,
              photoUrl: result.user!.photoURL,
              createdAt: DateTime.now(),
              isOnline: true,
              hasCreatedProfile: false,
            );

            final userData = {
              'id': result.user!.uid,
              'email': result.user!.email ?? '',
              'username': result.user!.email?.split('@')[0] ?? 'user',
              'displayName': result.user!.displayName,
              'photoUrl': result.user!.photoURL,
              'createdAt': DateTime.now(),
              'isOnline': true,
              'hasCreatedProfile': false,
            };

            await _firestore
                .collection('users')
                .doc(result.user!.uid)
                .set(userData);

            print('✅ User document created successfully');
            return newUser;
          } else {
            print('🔄 Updating existing user online status');
            // Update online status for existing user
            await _updateUserOnlineStatus(result.user!.uid, true);
            return existingUser;
          }
        }
        return null;
      } else {
        print("Error: Unsupported platform");
        return null;
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      if (currentUser != null) {
        await _updateUserOnlineStatus(currentUser!.uid, false);
      }
      await _auth.signOut();
    } catch (e) {
      throw e;
    }
  }

  Future<UserModel?> getUserData(String uid) async {
    try {
      final DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(uid)
          .get();

      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      throw e;
    }
  }

  Future<void> updateUserProfile({
    String? displayName,
    String? photoUrl,
    String? bio,
    int? age,
    String? location,
    List<String>? interests,
  }) async {
    try {
      if (currentUser != null) {
        final Map<String, dynamic> updates = {};

        if (displayName != null) updates['displayName'] = displayName;
        if (photoUrl != null) updates['photoUrl'] = photoUrl;
        if (bio != null) updates['bio'] = bio;
        if (age != null) updates['age'] = age;
        if (location != null) updates['location'] = location;
        if (interests != null) updates['interests'] = interests;

        updates['hasCreatedProfile'] = true;

        await _firestore
            .collection('users')
            .doc(currentUser!.uid)
            .update(updates);
      }
    } catch (e) {
      throw e;
    }
  }

  Future<void> _updateUserOnlineStatus(String uid, bool isOnline) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'isOnline': isOnline,
        'lastSeen': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      print('Error updating online status: $e');
    }
  }

  Future<bool> isUsernameAvailable(String username) async {
    try {
      final QuerySnapshot result = await _firestore
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      return result.docs.isEmpty;
    } catch (e) {
      throw e;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw e;
    }
  }
}
