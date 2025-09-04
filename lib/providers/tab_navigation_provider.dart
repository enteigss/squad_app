import 'package:flutter/foundation.dart';
import '../services/navigation_service.dart';

class TabNavigationProvider extends ChangeNotifier {
  int _selectedIndex = 0;
  
  int get selectedIndex => _selectedIndex;
  
  void setSelectedIndex(int index) {
    if (_selectedIndex != index) {
      _selectedIndex = index;
      notifyListeners();
    }
  }
  
  void navigateToHangouts({String? tab}) {
    setSelectedIndex(0);
    if (tab != null) {
      // Use NavigationService instead of storing context
      NavigationService.goToPath('/feed?tab=$tab');
    }
  }
  
  void navigateToCreate() {
    setSelectedIndex(1);
  }
  
  void navigateToProfile() {
    setSelectedIndex(2);
  }
}