import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sets up Firebase Core mocks for widget tests.
///
/// Call this in setUpAll() before any tests that render widgets
/// which instantiate Firebase services directly (e.g., DebugService,
/// NotificationService, BlockService).
///
/// Usage:
/// ```dart
/// setUpAll(() async {
///   await setupFirebaseForTesting();
/// });
/// ```
Future<void> setupFirebaseForTesting() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  setupFirebaseCoreMocks();
  await Firebase.initializeApp();
}
