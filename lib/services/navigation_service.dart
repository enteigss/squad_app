import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Global navigation service that provides access to navigation from anywhere in the app
class NavigationService {
  // Global navigator key that will be registered with GoRouter
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  
  /// Navigate to a specific path using GoRouter
  static void goToPath(String path) {
    debugPrint('🧭 NavigationService.goToPath() called with path: $path');
    
    final context = navigatorKey.currentContext;
    debugPrint('🔍 Navigator context available: ${context != null}');
    
    if (context != null) {
      debugPrint('🔍 Context mounted: ${context.mounted}');
      
      if (context.mounted) {
        debugPrint('✅ Context is valid, calling context.go("$path")');
        try {
          context.go(path);
          debugPrint('✅ context.go() call completed successfully');
        } catch (e) {
          debugPrint('💥 ERROR in context.go(): $e');
          debugPrint('🔍 Error type: ${e.runtimeType}');
        }
      } else {
        debugPrint('❌ Context is not mounted');
      }
    } else {
      debugPrint('❌ NavigationService: Unable to navigate - context not available');
    }
  }
  
  /// Navigate to a hangout detail page
  static void goToHangout(String hangoutId) {
    debugPrint('🎯 NavigationService.goToHangout() called with hangoutId: $hangoutId');
    final path = '/hangout/$hangoutId';
    debugPrint('🎯 Generated path: $path');
    goToPath(path);
  }
  
  /// Navigate back
  static void goBack() {
    final navigator = navigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
    }
  }
  
  /// Push a new route
  static Future<T?> pushNamed<T>(String routeName, {Object? arguments}) {
    final navigator = navigatorKey.currentState;
    if (navigator != null) {
      return navigator.pushNamed(routeName, arguments: arguments);
    }
    debugPrint('NavigationService: Unable to push route - navigator not available');
    return Future.value(null);
  }
  
  /// Replace current route
  static Future<T?> pushReplacementNamed<T>(String routeName, {Object? arguments}) {
    final navigator = navigatorKey.currentState;
    if (navigator != null) {
      return navigator.pushReplacementNamed(routeName, arguments: arguments);
    }
    debugPrint('NavigationService: Unable to replace route - navigator not available');
    return Future.value(null);
  }
  
  /// Get current context (useful for showing dialogs, snackbars, etc.)
  static BuildContext? get currentContext => navigatorKey.currentContext;
  
  /// Check if navigation is available
  static bool get isNavigationAvailable => 
      navigatorKey.currentContext != null && navigatorKey.currentContext!.mounted;
}