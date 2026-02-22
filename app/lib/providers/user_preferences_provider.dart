import 'package:flutter/foundation.dart';

class UserPreferencesProvider with ChangeNotifier {
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  void initialize() {
    // Initialize user preferences if needed
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}