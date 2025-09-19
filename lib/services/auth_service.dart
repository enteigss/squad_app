import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

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
          authProvider: 'email',
        );

        final userData = {
          'id': result.user!.uid,
          'email': email,
          'username': email.split('@')[0],
          'displayName': null,
          'createdAt': DateTime.now(),
          'isOnline': true,
          'hasCreatedProfile': false,
          'authProvider': 'email',
          'isEmailVerified': true,
        };

        await _firestore
            .collection('users')
            .doc(result.user!.uid)
            .set(userData);

        // Check for pending party pack invitations
        await _processPendingInvitations(email);

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
      debugPrint(
        '🚀 AuthService.signInWithGoogle: Starting Google Sign-In process',
      );

      // Log sign-in attempt to Crashlytics
      await FirebaseCrashlytics.instance.log('Google Sign-In attempt started');
      await FirebaseCrashlytics.instance.setCustomKey(
        'signin_attempt',
        DateTime.now().toIso8601String(),
      );

      final GoogleSignIn googleSignIn = GoogleSignIn.instance;
      debugPrint('🔧 Initializing GoogleSignIn with server client ID');
      googleSignIn.initialize(
        serverClientId:
            "555170207131-7svrdoua7njct4p8pebdrlfibshdbkih.apps.googleusercontent.com",
      );

      // Check if authenticate() is supported
      debugPrint(
        '🔍 Checking if authenticate() is supported: ${GoogleSignIn.instance.supportsAuthenticate()}',
      );
      if (GoogleSignIn.instance.supportsAuthenticate()) {
        debugPrint('🔐 Attempting Google authentication...');
        final GoogleSignInAccount? googleUser = await googleSignIn
            .authenticate();

        if (googleUser == null) {
          debugPrint('❌ Google authentication cancelled by user');
          return null; // User cancelled
        }

        debugPrint(
          '✅ Google authentication successful for: ${googleUser.email}',
        );

        // Validate BU email domain before creating Firebase account
        final email = googleUser.email;
        debugPrint('🎓 Validating BU email domain for: $email');
        if (!await _isBUEmail(email)) {
          await googleSignIn.signOut(); // Sign out from Google
          throw Exception(
            'Access restricted to Boston University students only. Please use your @bu.edu email address.',
          );
        }

        debugPrint('✅ BU email validation passed');

        // Get authentication details
        debugPrint('🔑 Getting Google authentication details...');
        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;
        debugPrint(
          '🔑 Google auth tokens received: idToken=${googleAuth.idToken != null}',
        );

        // Create Firebase credential and sign in
        debugPrint('🔥 Creating Firebase credential...');
        final credential = GoogleAuthProvider.credential(
          idToken: googleAuth.idToken,
        );

        debugPrint('🔥 Signing in to Firebase with Google credential...');
        final UserCredential result = await _auth.signInWithCredential(
          credential,
        );

        if (result.user != null) {
          debugPrint(
            '✅ Firebase authentication successful for user: ${result.user!.uid}',
          );
          debugPrint('📧 User email: ${result.user!.email}');
          debugPrint('👤 User display name: ${result.user!.displayName}');

          // Set user ID for analytics after a successful sign-in
          await _analytics.setUserId(id: result.user!.uid);
          debugPrint(
            'Successfully set User ID for Analytics: ${result.user!.uid}',
          );

          // Check if user document exists in Firestore
          debugPrint('🔍 Checking for existing user document in Firestore...');
          final existingUser = await getUserData(result.user!.uid);
          debugPrint('🔍 Existing user in Firestore: ${existingUser?.toMap()}');

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
              'authProvider': 'google',
              'isEmailVerified': true,
            };

            try {
              await _firestore
                  .collection('users')
                  .doc(result.user!.uid)
                  .set(userData);

              // Check for pending party pack invitations
              await _processPendingInvitations(result.user!.email ?? '');

              print('✅ User document created successfully');

              // Log successful sign-in to Crashlytics
              await FirebaseCrashlytics.instance.log(
                'Google Sign-In completed successfully',
              );
              await FirebaseCrashlytics.instance.setCustomKey(
                'signin_success',
                DateTime.now().toIso8601String(),
              );

              return newUser;
            } catch (e) {
              print('❌ Error creating user document: $e');
              // Still return the user model even if Firestore write fails
              // The auth state will be valid, and user can retry later
              return newUser;
            }
          } else {
            print('🔄 Updating existing user online status');
            // Update online status for existing user
            await _updateUserOnlineStatus(result.user!.uid, true);

            // Log successful sign-in to Crashlytics
            await FirebaseCrashlytics.instance.log(
              'Google Sign-In completed successfully (existing user)',
            );
            await FirebaseCrashlytics.instance.setCustomKey(
              'signin_success',
              DateTime.now().toIso8601String(),
            );

            return existingUser;
          }
        }
        return null;
      } else {
        print("Error: Unsupported platform");
        return null;
      }
    } catch (e) {
      debugPrint('❌ AuthService.signInWithGoogle error: $e');
      debugPrint('🔍 Error type: ${e.runtimeType}');

      if (e is FirebaseAuthException) {
        debugPrint(
          '🔥 Firebase Auth Error - Code: ${e.code}, Message: ${e.message}',
        );
      }

      // Log to Crashlytics for production debugging
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Google Sign-In failed',
        information: [
          'Platform: ${defaultTargetPlatform.name}',
          'Build mode: ${kReleaseMode ? "release" : "debug"}',
          'Error type: ${e.runtimeType}',
          if (e is FirebaseAuthException) 'Firebase Auth Code: ${e.code}',
        ],
        fatal: false,
      );

      rethrow;
    }
  }

  Future<UserModel?> signInWithApple() async {
    try {
      debugPrint(
        '🍎 AuthService.signInWithApple: Starting Apple Sign-In process',
      );

      // Log sign-in attempt to Crashlytics
      await FirebaseCrashlytics.instance.log('Apple Sign-In attempt started');
      await FirebaseCrashlytics.instance.setCustomKey(
        'signin_attempt_apple',
        DateTime.now().toIso8601String(),
      );

      debugPrint('🍎 Using Firebase native Apple Sign In...');

      // Create Apple auth provider with scopes
      final appleAuthProvider = AppleAuthProvider()
        ..addScope("email")
        ..addScope("name");

      debugPrint('🔥 Signing in to Firebase with Apple provider...');
      final UserCredential result = await _auth.signInWithProvider(
        appleAuthProvider,
      );

      if (result.user == null) {
        debugPrint('❌ Firebase authentication failed - no user returned');
        throw Exception('Apple Sign In failed');
      }

      debugPrint(
        '✅ Firebase authentication successful for user: ${result.user!.uid}',
      );
      debugPrint('📧 Firebase User email: ${result.user!.email}');
      debugPrint('👤 Firebase User display name: ${result.user!.displayName}');

      // Determine the email to validate
      String? emailToValidate = result.user!.email;

      // Determine if email verification is needed
      bool needsEmailVerification = false;
      bool isBUEmail = false;

      if (emailToValidate == null || emailToValidate.isEmpty) {
        debugPrint(
          '⚠️ No email provided by Apple - will need email verification flow',
        );
        // Set placeholder email for users who hide their email
        emailToValidate = 'hidden-email@apple.privaterelay.com';
        needsEmailVerification = true;
      } else {
        // Check if this is a BU email or test account
        isBUEmail = await _isBUEmail(emailToValidate);

        if (!isBUEmail) {
          debugPrint('📧 Non-BU email provided: $emailToValidate - will need verification');
          needsEmailVerification = true;
        }
      }

      debugPrint('🎓 Email validation result - isBUEmail: $isBUEmail, needsVerification: $needsEmailVerification');

      // Set user ID for analytics
      await _analytics.setUserId(id: result.user!.uid);
      debugPrint('✅ Analytics User ID set: ${result.user!.uid}');

      // Check if user document exists in Firestore
      debugPrint('🔍 Checking for existing user document in Firestore...');
      final existingUser = await getUserData(result.user!.uid);

      if (existingUser == null) {
        debugPrint('➕ Creating new user document for Apple Sign-In');

        // Create new user document
        final UserModel newUser = UserModel(
          id: result.user!.uid,
          email: emailToValidate,
          username: _generateUsernameFromEmail(emailToValidate),
          displayName: result.user!.displayName,
          photoUrl: result.user!.photoURL,
          createdAt: DateTime.now(),
          isOnline: true,
          hasCreatedProfile: false,
          authProvider: 'apple',
          isEmailVerified: !needsEmailVerification,
          verifiedEmail: !needsEmailVerification ? emailToValidate : null,
        );

        final userData = newUser.toMap();

        try {
          await _firestore
              .collection('users')
              .doc(result.user!.uid)
              .set(userData);


          debugPrint('✅ Apple user document created successfully');

          // Log successful sign-in to Crashlytics
          await FirebaseCrashlytics.instance.log(
            'Apple Sign-In completed successfully',
          );
          await FirebaseCrashlytics.instance.setCustomKey(
            'signin_success_apple',
            DateTime.now().toIso8601String(),
          );

          return newUser;
        } catch (e) {
          debugPrint('❌ Error creating user document: $e');
          // Still return the user model even if Firestore write fails
          return newUser;
        }
      } else {
        debugPrint('🔄 Updating existing Apple user online status');
        // Update online status for existing user
        await _updateUserOnlineStatus(result.user!.uid, true);

        // Log successful sign-in to Crashlytics
        await FirebaseCrashlytics.instance.log(
          'Apple Sign-In completed successfully (existing user)',
        );
        await FirebaseCrashlytics.instance.setCustomKey(
          'signin_success_apple',
          DateTime.now().toIso8601String(),
        );

        return existingUser;
      }
    } catch (e) {
      debugPrint('❌ AuthService.signInWithApple error: $e');
      debugPrint('🔍 Error type: ${e.runtimeType}');

      if (e is FirebaseAuthException) {
        debugPrint('🔍 Firebase Auth Error Code: ${e.code}');
        debugPrint('🔍 Firebase Auth Error Message: ${e.message}');
        debugPrint('🔍 Firebase Auth Error Details: ${e.toString()}');
      }

      // Log to Crashlytics for production debugging
      await FirebaseCrashlytics.instance.recordError(
        e,
        StackTrace.current,
        reason: 'Apple Sign-In failed',
        information: [
          'Platform: ${defaultTargetPlatform.name}',
          'Build mode: ${kReleaseMode ? "release" : "debug"}',
          'Error type: ${e.runtimeType}',
          if (e is FirebaseAuthException) 'Firebase Auth Error Code: ${e.code}',
        ],
        fatal: false,
      );

      rethrow;
    }
  }

  String _generateUsernameFromEmail(String email) {
    if (email == 'needs-verification@temp.local') {
      return 'user_${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    }
    return email.split('@')[0];
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
      print('❌ getUserData error for uid $uid: $e');
      throw e;
    }
  }

  Future<void> updateUserProfile({
    String? displayName,
    String? photoUrl,
    String? bio,
    String? classYear,
    String? location,
    List<String>? interests,
    String? gender,
  }) async {
    try {
      if (currentUser != null) {
        final Map<String, dynamic> updates = {};

        if (displayName != null) updates['displayName'] = displayName;
        if (photoUrl != null) updates['photoUrl'] = photoUrl;
        if (bio != null) updates['bio'] = bio;
        if (classYear != null) updates['classYear'] = classYear;
        if (location != null) updates['location'] = location;
        if (interests != null) updates['interests'] = interests;
        if (gender != null) updates['gender'] = gender;

        // Basic profile created, but not preferences yet
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

  Future<bool> _isBUEmail(String email) async {
    final emailLower = email.toLowerCase();

    // Check BU domain first
    if (emailLower.endsWith('@bu.edu')) {
      return true;
    }

    // Check server-side test accounts from Firestore
    try {
      debugPrint('🔍 Checking server-side test emails for: $email');
      final testAccountsDoc = await _firestore
          .collection('config')
          .doc('test_accounts')
          .get();

      if (testAccountsDoc.exists) {
        final data = testAccountsDoc.data() as Map<String, dynamic>;
        final serverTestEmails = List<String>.from(data['emails'] ?? []);
        debugPrint('📋 Server test emails: $serverTestEmails');

        if (serverTestEmails.contains(emailLower)) {
          debugPrint('✅ Email found in server test list');
          return true;
        }
      } else {
        debugPrint('📄 No server test accounts document found');
      }
    } catch (e) {
      debugPrint('❌ Error checking server test accounts: $e');
    }

    // Fallback to hardcoded test accounts if Firestore fails or email not found
    const fallbackTestAccounts = [
      'michael@geml.co',
      'green.wb.evan@gmail.com',
      'alexhu124@gmail.com',
      'greenmichaeltodd@gmail.com',
      'sheriese@gmail.com',
      'stosh.janik@gmail.com',
    ];

    final isInFallback = fallbackTestAccounts.contains(emailLower);
    if (isInFallback) {
      debugPrint('✅ Email found in fallback hardcoded list');
    } else {
      debugPrint('❌ Email not found in any test lists');
    }

    return isInFallback;
  }

  Future<void> _processPendingInvitations(String userEmail) async {
    try {
      // Find all pending invitations for this email
      final invitationsQuery = await _firestore
          .collection('party_invitations')
          .where('inviteeEmail', isEqualTo: userEmail)
          .where('processed', isEqualTo: false)
          .get();

      if (invitationsQuery.docs.isEmpty) {
        print('No pending party pack invitations found for $userEmail');
        return;
      }

      print(
        'Found ${invitationsQuery.docs.length} pending party pack invitations for $userEmail',
      );

      // Process each invitation
      for (final invitationDoc in invitationsQuery.docs) {
        final invitationData = invitationDoc.data();
        final inviterEmail = invitationData['inviterEmail'] as String;

        print('Processing party pack invitation from $inviterEmail');

        // Add the inviter to this user's incoming party pack requests
        await _firestore
            .collection('users')
            .where('email', isEqualTo: userEmail)
            .limit(1)
            .get()
            .then((userQuery) async {
              if (userQuery.docs.isNotEmpty) {
                final userDoc = userQuery.docs.first;
                await userDoc.reference.update({
                  'incomingPartyPackRequests': FieldValue.arrayUnion([
                    inviterEmail,
                  ]),
                });
                print(
                  'Added $inviterEmail to incoming party pack requests for $userEmail',
                );
              }
            });

        // Mark invitation as processed
        await invitationDoc.reference.update({
          'processed': true,
          'processedAt': FieldValue.serverTimestamp(),
        });

        print('Marked invitation from $inviterEmail as processed');
      }

      print('Successfully processed all pending invitations for $userEmail');
    } catch (e) {
      print('Error processing pending invitations for $userEmail: $e');
      // Don't throw error - this shouldn't block user registration
    }
  }

  /// Re-authenticate user with Google Sign In
  Future<bool> reauthenticateWithGoogle() async {
    try {
      debugPrint('🔐 Starting Google re-authentication...');

      final GoogleSignIn googleSignIn = GoogleSignIn.instance;
      googleSignIn.initialize(
        serverClientId:
            "555170207131-7svrdoua7njct4p8pebdrlfibshdbkih.apps.googleusercontent.com",
      );

      // Disconnect first to force account selection
      await googleSignIn.disconnect();

      final GoogleSignInAccount? googleUser = await googleSignIn.authenticate();
      if (googleUser == null) {
        debugPrint('❌ Google re-authentication cancelled by user');
        return false;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // Re-authenticate the current user
      await _auth.currentUser?.reauthenticateWithCredential(credential);

      debugPrint('✅ Google re-authentication successful');
      return true;
    } catch (e) {
      debugPrint('❌ Google re-authentication failed: $e');
      return false;
    }
  }

  /// Re-authenticate user with Apple Sign In
  Future<bool> reauthenticateWithApple() async {
    try {
      debugPrint('🍎 Starting Apple re-authentication...');

      final appleAuthProvider = AppleAuthProvider()
        ..addScope("email")
        ..addScope("name");

      final UserCredential result = await _auth.signInWithProvider(appleAuthProvider);

      if (result.user == null) {
        debugPrint('❌ Apple re-authentication failed - no user returned');
        return false;
      }

      debugPrint('✅ Apple re-authentication successful');
      return true;
    } catch (e) {
      debugPrint('❌ Apple re-authentication failed: $e');
      return false;
    }
  }

  /// Re-authenticate user based on their auth provider
  Future<bool> reauthenticateUser() async {
    try {
      final user = currentUser;
      if (user == null) return false;

      // Get user data to determine auth provider
      final userData = await getUserData(user.uid);
      if (userData == null) return false;

      final authProvider = userData.authProvider;

      switch (authProvider) {
        case 'google':
          return await reauthenticateWithGoogle();
        case 'apple':
          return await reauthenticateWithApple();
        default:
          debugPrint('❌ Unsupported auth provider for re-authentication: $authProvider');
          return false;
      }
    } catch (e) {
      debugPrint('❌ Re-authentication failed: $e');
      return false;
    }
  }
}
