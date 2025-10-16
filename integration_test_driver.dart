// This file provides extended capabilities for integration tests including:
// - Performance profiling
// - Screenshot capture
// - Timeline tracing
// - Running tests on real devices
//
// To use this driver with integration tests, run:
// flutter drive --driver=integration_test_driver.dart --target=integration_test/app_test.dart

import 'package:integration_test/integration_test_driver.dart';

Future<void> main() => integrationDriver();
