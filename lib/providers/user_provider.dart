import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

class UserProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  
  List<UserModel> _searchResults = [];
  bool _isSearching = false;
  String? _searchError;

  List<UserModel> get searchResults => _searchResults;
  bool get isSearching => _isSearching;
  String? get searchError => _searchError;

  Future<void> searchUsers(String query) async {
    if (query.trim().isEmpty) {
      _searchResults.clear();
      notifyListeners();
      return;
    }

    try {
      _setSearching(true);
      _clearSearchError();
      
      _searchResults = await _firestoreService.searchUsers(query.trim());
    } catch (e) {
      _searchError = 'Failed to search users: ${e.toString()}';
      _searchResults.clear();
    } finally {
      _setSearching(false);
    }
  }

  void clearSearchResults() {
    _searchResults.clear();
    _clearSearchError();
    notifyListeners();
  }

  void _setSearching(bool searching) {
    _isSearching = searching;
    notifyListeners();
  }

  void _clearSearchError() {
    _searchError = null;
    notifyListeners();
  }

  void clearSearchError() {
    _clearSearchError();
  }
}