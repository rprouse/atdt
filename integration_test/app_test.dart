// Launch on a device. With an archive already downloaded (e.g. from an
// earlier run), also walks library -> issue -> phile -> reader -> back.
import 'package:atdt/library/issues_screen.dart';
import 'package:atdt/main.dart' as app;
import 'package:atdt/reader/reader_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Pumps until [finder] matches or ~10 s pass: storage is real I/O here,
/// and pumpAndSettle only waits for frames.
Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 100 && finder.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('launches into the library and opens a stored phile', (
    tester,
  ) async {
    app.main();
    await pumpUntil(tester, find.byType(IssuesScreen));
    expect(find.byType(IssuesScreen), findsOneWidget);

    final issue = find.textContaining(RegExp(r'· \d+ philes$'));
    await pumpUntil(tester, issue);
    if (issue.evaluate().isEmpty) {
      markTestSkipped('No issues downloaded on this device yet');
      return;
    }

    await tester.tap(issue.first);
    await pumpUntil(tester, find.byType(ListTile));
    await tester.tap(find.byType(ListTile).first);
    await pumpUntil(tester, find.byType(ReaderView));
    expect(find.byType(ReaderView), findsOneWidget);

    await tester.pageBack();
    await pumpUntil(tester, find.byType(ListTile));
    expect(find.byType(ReaderView), findsNothing);
  });
}
