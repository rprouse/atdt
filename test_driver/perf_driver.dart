import 'package:flutter_driver/flutter_driver.dart' as driver;
import 'package:integration_test/integration_test_driver.dart';

/// Saves each `watchPerformance` report to build/ as a timeline summary.
Future<void> main() => integrationDriver(
  responseDataCallback: (data) async {
    if (data == null) return;
    for (final MapEntry(:key, :value) in data.entries) {
      await writeResponseData(
        value as Map<String, dynamic>,
        testOutputFilename: '$key.timeline_summary',
        destinationDirectory: driver.testOutputsDirectory,
      );
    }
  },
);
