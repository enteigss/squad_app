import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:network_image_mock/network_image_mock.dart';

/// Test helper utilities for widget and integration tests
///
/// Provides common setup functions and utilities to reduce boilerplate.

/// Wraps a widget with MaterialApp for testing
///
/// Usage:
/// ```dart
/// await tester.pumpWidget(wrapWithMaterialApp(MyWidget()));
/// ```
Widget wrapWithMaterialApp(
  Widget child, {
  ThemeData? theme,
  NavigatorObserver? navigatorObserver,
}) {
  return MaterialApp(
    home: child,
    theme: theme ?? ThemeData.light(),
    navigatorObservers: navigatorObserver != null ? [navigatorObserver] : [],
  );
}

/// Wraps a widget with MaterialApp and providers for testing
///
/// Usage:
/// ```dart
/// await tester.pumpWidget(wrapWithProviders(
///   MyWidget(),
///   providers: [
///     ChangeNotifierProvider(create: (_) => mockAuthProvider),
///   ],
/// ));
/// ```
Widget wrapWithProviders(
  Widget child, {
  required List<SingleChildWidget> providers,
  ThemeData? theme,
  NavigatorObserver? navigatorObserver,
}) {
  return MultiProvider(
    providers: providers,
    child: MaterialApp(
      home: child,
      theme: theme ?? ThemeData.light(),
      navigatorObservers: navigatorObserver != null ? [navigatorObserver] : [],
    ),
  );
}

/// Wraps a widget with Scaffold for testing widgets that need Scaffold context
Widget wrapWithScaffold(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: child,
    ),
  );
}

/// Pumps widget and handles network images
///
/// Use this when testing widgets that contain CachedNetworkImage
///
/// Usage:
/// ```dart
/// await pumpWidgetWithNetworkImages(tester, MyWidget());
/// ```
Future<void> pumpWidgetWithNetworkImages(
  WidgetTester tester,
  Widget widget,
) async {
  await mockNetworkImagesFor(() => tester.pumpWidget(widget));
}

/// Pumps widget and settles all animations
///
/// Usage:
/// ```dart
/// await pumpAndSettleWidget(tester, MyWidget());
/// ```
Future<void> pumpAndSettleWidget(
  WidgetTester tester,
  Widget widget, {
  Duration? duration,
}) async {
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle(duration ?? const Duration(milliseconds: 100));
}

/// Finds widget by type and taps it
///
/// Usage:
/// ```dart
/// await tapWidgetByType<ElevatedButton>(tester);
/// ```
Future<void> tapWidgetByType<T extends Widget>(WidgetTester tester) async {
  final finder = find.byType(T);
  expect(finder, findsOneWidget, reason: 'Expected to find one $T widget');
  await tester.tap(finder);
  await tester.pump();
}

/// Finds widget by key and taps it
///
/// Usage:
/// ```dart
/// await tapWidgetByKey(tester, Key('submit_button'));
/// ```
Future<void> tapWidgetByKey(WidgetTester tester, Key key) async {
  final finder = find.byKey(key);
  expect(finder, findsOneWidget, reason: 'Expected to find widget with key $key');
  await tester.tap(finder);
  await tester.pump();
}

/// Enters text into a TextField found by key
///
/// Usage:
/// ```dart
/// await enterTextByKey(tester, Key('email_field'), 'test@bu.edu');
/// ```
Future<void> enterTextByKey(
  WidgetTester tester,
  Key key,
  String text,
) async {
  final finder = find.byKey(key);
  expect(finder, findsOneWidget, reason: 'Expected to find TextField with key $key');
  await tester.enterText(finder, text);
  await tester.pump();
}

/// Scrolls until a widget is visible
///
/// Usage:
/// ```dart
/// await scrollUntilVisible(tester, find.text('Item 50'), find.byType(ListView));
/// ```
Future<void> scrollUntilVisible(
  WidgetTester tester,
  Finder itemFinder,
  Finder scrollableFinder, {
  double delta = 100,
  int maxScrolls = 50,
}) async {
  int scrolls = 0;
  while (scrolls < maxScrolls) {
    if (tester.any(itemFinder)) {
      return;
    }
    await tester.drag(scrollableFinder, Offset(0, -delta));
    await tester.pump();
    scrolls++;
  }
  fail('Could not find widget after $maxScrolls scrolls');
}

/// Extension on WidgetTester for common operations
extension WidgetTesterExtensions on WidgetTester {
  /// Pumps and waits for all animations to complete
  Future<void> pumpUntilSettled({Duration? timeout}) async {
    await pumpAndSettle(timeout ?? const Duration(seconds: 5));
  }

  /// Finds and taps a widget containing specific text
  Future<void> tapText(String text) async {
    final finder = find.text(text);
    expect(finder, findsWidgets, reason: 'Expected to find text "$text"');
    await tap(finder.first);
    await pump();
  }

  /// Verifies a widget with specific text exists
  void expectText(String text, {bool exists = true}) {
    final finder = find.text(text);
    if (exists) {
      expect(finder, findsWidgets, reason: 'Expected to find text "$text"');
    } else {
      expect(finder, findsNothing, reason: 'Expected NOT to find text "$text"');
    }
  }
}
