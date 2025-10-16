# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Flutter application named "squad_app" - a cross-platform mobile app supporting iOS, Android, Web, Windows, macOS, and Linux. The project follows standard Flutter conventions and is currently a basic counter app starter template.

## Common Development Commands

### Dependencies and Setup
```bashB
flutter pub get          # Install dependencies
flutter pub upgrade      # Upgrade dependencies to latest versions
```

### Running the Application
```bash
flutter run                    # Run on connected device/emulator
flutter run -d chrome         # Run on web browser
flutter run -d windows        # Run on Windows desktop
flutter run --hot-reload      # Enable hot reload (default)
flutter run --release         # Run in release mode
```

### Testing
```bash
# Unit and Widget Tests
flutter test                   # Run all unit and widget tests
flutter test test/widget_test.dart  # Run specific test file
flutter test --coverage       # Run tests with coverage report

# Integration Tests
flutter test integration_test  # Run all integration tests
flutter test integration_test/app_test.dart  # Run specific integration test

# Integration Tests with Driver (for performance profiling, screenshots, etc.)
flutter drive --driver=integration_test_driver.dart --target=integration_test/app_test.dart
```

### Code Quality and Analysis
```bash
flutter analyze               # Static analysis of Dart code
flutter format .              # Format all Dart code
flutter format --set-exit-if-changed .  # Format and exit with error if changes needed
```

### Building
```bash
flutter build apk            # Build Android APK
flutter build appbundle      # Build Android App Bundle
flutter build ios            # Build iOS app (requires macOS)
flutter build web            # Build for web deployment
flutter build windows        # Build Windows desktop app
flutter build macos          # Build macOS desktop app (requires macOS)
flutter build linux          # Build Linux desktop app
```

### Cleaning
```bash
flutter clean                # Clean build artifacts
flutter pub cache repair     # Repair pub cache if corrupted
```

## Project Architecture

### Directory Structure
- `lib/` - Main Dart application code
  - `main.dart` - Application entry point with MaterialApp setup
- `test/` - Widget and unit tests
- `integration_test/` - Integration tests for full app testing
- `integration_test_driver.dart` - Test driver for advanced integration test features
- `android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/` - Platform-specific code and configurations
- `pubspec.yaml` - Project dependencies and configuration
- `analysis_options.yaml` - Dart analyzer configuration using flutter_lints

### Current Implementation
- Single-page counter application using StatefulWidget pattern
- Material Design theming with ColorScheme.fromSeed
- Standard Flutter project structure with minimal dependencies
- Uses flutter_lints for code quality enforcement

### Key Dependencies
- `flutter` - Core Flutter framework
- `cupertino_icons` - iOS-style icons
- `flutter_test` - Testing framework (unit and widget tests)
- `integration_test` - Integration testing framework
- `flutter_lints` - Lint rules for code quality

## Development Notes

- Project uses Dart SDK ^3.8.1
- Analysis options include package:flutter_lints/flutter.yaml for recommended lints
- Hot reload is available for faster development iteration
- Cross-platform support is configured for all major platforms
- No custom assets or fonts currently configured