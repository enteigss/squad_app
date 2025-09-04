import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TabNavigationProvider extends ChangeNotifier {
  int _selectedIndex = 0;
  BuildContext? _context;
  
  int get selectedIndex => _selectedIndex;
  
  void setContext(BuildContext context) {
    _context = context;
  }
  
  void setSelectedIndex(int index) {
    if (_selectedIndex != index) {
      _selectedIndex = index;
      notifyListeners();
    }
  }
  
  void navigateToHangouts({String? tab}) {
    setSelectedIndex(0);
    if (tab != null && _context != null) {
      // Use GoRouter to navigate with tab parameter
      GoRouter.of(_context!).go('/feed?tab=$tab');
    }
  }
  
  void navigateToCreate() {
    setSelectedIndex(1);
  }
  
  void navigateToProfile() {
    setSelectedIndex(2);
  }
}