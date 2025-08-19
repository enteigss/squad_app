import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserPreferencesProvider with ChangeNotifier {
  bool? _squadsOptIn;
  bool _isLoading = false;
  String? _error;

  bool? get squadsOptIn => _squadsOptIn;
  bool get isLoading => _isLoading;
  String? get error => _error;

  void initialize(bool? initialSquadsOptIn) {
    _squadsOptIn = initialSquadsOptIn;
  }

  Future<void> updateSquadsOptIn(bool optIn) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      // Update Firestore directly
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'squadsOptIn': optIn,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update local state
      _squadsOptIn = optIn;
    } catch (e) {
      _error = e.toString();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}