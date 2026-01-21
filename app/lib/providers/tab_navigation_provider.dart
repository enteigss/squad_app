import 'package:flutter/foundation.dart';

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
  }

  void navigateToCreate() {
    // No longer tied to PageView index
  }

  void navigateToProfile() {
    setSelectedIndex(1);
  }

  void navigateToPlans() {
    setSelectedIndex(2);
  }

  void navigateToConnect() {
    setSelectedIndex(3);
  }
}
