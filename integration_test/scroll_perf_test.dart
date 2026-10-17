// Frame timing while flinging through the 10,000-line fixture.
//
//   flutter drive --profile --no-dds \
//     --driver=test_driver/perf_driver.dart \
//     --target=integration_test/scroll_perf_test.dart -d <device>
//
// Writes build/scroll_perf_<font>.timeline_summary.json for each font.
import 'package:atdt/reader/reader_font.dart';
import 'package:atdt/reader/reader_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'fixture_text.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Fonts come from the manifest at runtime, so one test measures each in
  // turn, with a separate report per font.
  testWidgets('fling scroll, for every font', (tester) async {
    final fonts = await FontRegistry.loadFromBundle(rootBundle);
    final text = tenThousandLines();
    for (final font in fonts.fonts) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            body: ReaderView(
              key: ValueKey(font.id),
              text: text,
              font: font,
              foreground: Colors.greenAccent,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final list = find.byType(ListView);
      await binding.watchPerformance(() async {
        for (var i = 0; i < 6; i++) {
          await tester.fling(list, const Offset(0, -600), 4000);
          await tester.pumpAndSettle();
        }
        for (var i = 0; i < 3; i++) {
          await tester.fling(list, const Offset(0, 600), 4000);
          await tester.pumpAndSettle();
        }
      }, reportKey: 'scroll_perf_${font.id}');
    }
  });
}
