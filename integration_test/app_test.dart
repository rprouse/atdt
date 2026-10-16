import 'package:atdt/main.dart' as app;
import 'package:atdt/reader/reader_view.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app launches into the reader', (tester) async {
    app.main();
    // Asset loading is real I/O on a device; pumpAndSettle only waits for
    // frames, so poll until the document has been read.
    for (
      var i = 0;
      i < 100 && find.byType(ReaderView).evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();

    expect(
      find.byType(ReaderView),
      findsOneWidget,
      reason: find.byType(Text).evaluate().map((e) => e.widget).join('\n'),
    );
  });
}
