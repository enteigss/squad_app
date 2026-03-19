import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:squad_app/providers/auth_provider.dart';
import 'package:squad_app/providers/post_provider.dart';
import 'package:squad_app/providers/tab_navigation_provider.dart';

/// Extension on WidgetTester to pump the app with all necessary providers
///
/// This simplifies widget tests by providing a consistent app setup.
///
/// Usage:
/// ```dart
/// testWidgets('my test', (tester) async {
///   await tester.pumpApp(
///     MyWidget(),
///     authProvider: mockAuthProvider,
///     postProvider: mockPostProvider,
///   );
/// });
/// ```
extension PumpApp on WidgetTester {
  /// Pumps a widget wrapped with the app's providers
  Future<void> pumpApp(
    Widget widget, {
    AuthProvider? authProvider,
    PostProvider? postProvider,
    TabNavigationProvider? tabNavigationProvider,
    ThemeData? theme,
    List<NavigatorObserver>? navigatorObservers,
  }) async {
    final providers = <SingleChildWidget>[];

    if (authProvider != null) {
      providers.add(
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
      );
    }

    if (postProvider != null) {
      providers.add(
        ChangeNotifierProvider<PostProvider>.value(value: postProvider),
      );
    }

    if (tabNavigationProvider != null) {
      providers.add(
        ChangeNotifierProvider<TabNavigationProvider>.value(
            value: tabNavigationProvider),
      );
    }

    Widget app = MaterialApp(
      home: widget,
      theme: theme ?? ThemeData.light(),
      navigatorObservers: navigatorObservers ?? [],
    );

    if (providers.isNotEmpty) {
      app = MultiProvider(
        providers: providers,
        child: app,
      );
    }

    await pumpWidget(app);
  }

  /// Pumps a widget wrapped in Scaffold (for widgets that need Scaffold context)
  Future<void> pumpWidgetInScaffold(Widget widget) async {
    await pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: widget,
        ),
      ),
    );
  }

  /// Pumps and waits for async operations to complete
  Future<void> pumpAndWait({Duration duration = const Duration(milliseconds: 100)}) async {
    await pump(duration);
    await pumpAndSettle();
  }
}
