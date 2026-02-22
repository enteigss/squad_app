import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FirestoreConfigSetup {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// One-time setup to create the test accounts document in Firestore
  /// Call this method once to initialize the server-side test email list
  static Future<void> setupTestAccountsDocument() async {
    try {
      debugPrint('🔧 Setting up Firestore test accounts document...');
      
      // Initial list of server-side test emails
      // You can modify this list and run the setup again to update
      final testEmails = [
        'new.tester1@example.com',
        'new.tester2@example.com',
        'additional.tester@gmail.com',
        // Add more test emails here as needed
      ];

      await _firestore
          .collection('config')
          .doc('test_accounts')
          .set({
            'emails': testEmails,
            'created_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
            'description': 'Server-side test email accounts for BU validation',
          });

      debugPrint('✅ Test accounts document created successfully');
      debugPrint('📋 Server test emails: $testEmails');
      debugPrint('🔍 You can now manage test emails in Firebase Console:');
      debugPrint('   Firestore → config → test_accounts → emails');
      
    } catch (e) {
      debugPrint('❌ Error setting up test accounts document: $e');
      rethrow;
    }
  }

  /// Add a new test email to the server-side list
  static Future<void> addTestEmail(String email) async {
    try {
      debugPrint('➕ Adding test email: $email');
      
      await _firestore
          .collection('config')
          .doc('test_accounts')
          .update({
            'emails': FieldValue.arrayUnion([email.toLowerCase()]),
            'updated_at': FieldValue.serverTimestamp(),
          });

      debugPrint('✅ Test email added successfully');
    } catch (e) {
      debugPrint('❌ Error adding test email: $e');
      rethrow;
    }
  }

  /// Remove a test email from the server-side list
  static Future<void> removeTestEmail(String email) async {
    try {
      debugPrint('➖ Removing test email: $email');
      
      await _firestore
          .collection('config')
          .doc('test_accounts')
          .update({
            'emails': FieldValue.arrayRemove([email.toLowerCase()]),
            'updated_at': FieldValue.serverTimestamp(),
          });

      debugPrint('✅ Test email removed successfully');
    } catch (e) {
      debugPrint('❌ Error removing test email: $e');
      rethrow;
    }
  }

  /// Get current list of server-side test emails
  static Future<List<String>> getTestEmails() async {
    try {
      final doc = await _firestore
          .collection('config')
          .doc('test_accounts')
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return List<String>.from(data['emails'] ?? []);
      }
      return [];
    } catch (e) {
      debugPrint('❌ Error getting test emails: $e');
      return [];
    }
  }
}