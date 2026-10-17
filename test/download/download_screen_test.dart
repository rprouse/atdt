import 'package:atdt/app.dart';
import 'package:atdt/download/download_controller.dart';
import 'package:atdt/download/download_screen.dart';
import 'package:atdt/storage/archive_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/archive_harness.dart';

Future<void> _pumpScreen(
  WidgetTester tester, {
  required ArchiveDatabase db,
  required FakeArchiveSource source,
}) async {
  addTearDown(db.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: archiveOverrides(database: db, source: source),
      child: const MaterialApp(home: DownloadScreen()),
    ),
  );
  await tester.pumpAndSettle();
}

String _counts(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('counts'))).data!;

void main() {
  testWidgets('first launch explains the download and its size', (
    tester,
  ) async {
    await _pumpScreen(
      tester,
      db: memoryArchiveDatabase(),
      source: FakeArchiveSource([1, 2]),
    );

    expect(_counts(tester), '0 issues, 0 philes stored');
    expect(
      find.textContaining('about $archiveDownloadMegabytes MB'),
      findsOneWidget,
    );
    expect(find.text('Download archive'), findsOneWidget);
  });

  testWidgets('downloading stores every issue and reports the counts', (
    tester,
  ) async {
    final source = FakeArchiveSource([1, 2]);
    await _pumpScreen(tester, db: memoryArchiveDatabase(), source: source);

    await tester.tap(find.text('Download archive'));
    await tester.pumpAndSettle();

    expect(source.fetched, [1, 2]);
    expect(_counts(tester), '2 issues, 6 philes stored');
    expect(find.text('Stored 2 new issues.'), findsOneWidget);
    expect(find.text('Check for new issues'), findsOneWidget);
  });

  testWidgets('offline shows a clear error and a retry', (tester) async {
    final source = FakeArchiveSource([1])..offline = true;
    await _pumpScreen(tester, db: memoryArchiveDatabase(), source: source);

    await tester.tap(find.text('Download archive'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('download-error')), findsOneWidget);
    expect(
      find.textContaining("Can't reach the Phrack archive"),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);

    source.offline = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(_counts(tester), '1 issue, 3 philes stored');
  });

  testWidgets('a download interrupted by the app dying resumes at launch', (
    tester,
  ) async {
    final db = memoryArchiveDatabase();
    addTearDown(db.close);
    // State as left by a run that was killed after issue 1.
    final source = FakeArchiveSource([1]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: archiveOverrides(database: db, source: source),
        child: const MaterialApp(home: DownloadScreen()),
      ),
    );
    await tester.tap(find.text('Download archive'));
    await tester.pumpAndSettle();
    await db.setSetting(downloadStateKey, 'requested');

    // Relaunch: a fresh app with one more issue available.
    source
      ..issues = [1, 2]
      ..fetched.clear();
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      ProviderScope(
        overrides: archiveOverrides(database: db, source: source),
        child: const AtdtApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(source.fetched, [2], reason: 'issue 1 is not downloaded again');
    expect(await db.storedIssueNumbers(), {1, 2});
    expect(await db.setting(downloadStateKey), isNot('requested'));
  });
}
