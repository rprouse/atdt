import 'package:atdt/app.dart';
import 'package:atdt/library/issue_screen.dart';
import 'package:atdt/library/issues_screen.dart';
import 'package:atdt/library/library_providers.dart';
import 'package:atdt/reader/reader_view.dart';
import 'package:atdt/storage/archive_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/archive_harness.dart';
import '../helpers/reader_harness.dart';

Future<ArchiveDatabase> _seeded() async {
  final db = memoryArchiveDatabase();
  await seedLibrary(db);
  return db;
}

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  required ArchiveDatabase db,
  FakeArchiveSource? source,
}) async {
  setSurface(tester, const Size(390, 844));
  addTearDown(tester.view.reset);
  addTearDown(db.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: archiveOverrides(database: db, source: source),
      child: MaterialApp(home: home),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadReaderFonts);

  group('issues screen', () {
    testWidgets('lists every issue newest first, with dates and state', (
      tester,
    ) async {
      await _pump(tester, const IssuesScreen(), db: await _seeded());

      final titles = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .map((t) => (t.title! as Text).data)
          .toList();
      expect(titles, [
        'Issue 100',
        'Issue 99',
        'Issue 98',
        'Issue 97',
        'Issue 96',
      ]);
      expect(find.text('9 Mar 1999 · 3 philes'), findsOneWidget);
      expect(find.text('8 Mar 1998 · 40 philes'), findsOneWidget);
      expect(find.text('10 Mar 2000 · Not downloaded'), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_outlined), findsNWidgets(3));
    });

    testWidgets('first launch explains the download and starts it', (
      tester,
    ) async {
      final source = FakeArchiveSource([1, 2]);
      await _pump(
        tester,
        const IssuesScreen(),
        db: memoryArchiveDatabase(),
        source: source,
      );

      expect(find.byKey(const ValueKey('first-launch')), findsOneWidget);
      expect(find.textContaining('about 31 MB'), findsOneWidget);
      expect(source.fetched, isEmpty, reason: 'nothing starts unasked');

      await tester.tap(find.text('Download the archive'));
      await tester.pumpAndSettle();

      expect(source.fetched, [1, 2]);
      expect(find.text('Issue 2'), findsOneWidget);
      expect(find.text('Issue 1'), findsOneWidget);
      expect(find.byKey(const ValueKey('first-launch')), findsNothing);
    });

    testWidgets('first launch shows an offline error with a retry', (
      tester,
    ) async {
      final source = FakeArchiveSource([1])..offline = true;
      await _pump(
        tester,
        const IssuesScreen(),
        db: memoryArchiveDatabase(),
        source: source,
      );

      await tester.tap(find.text('Download the archive'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining("Can't reach the Phrack archive"),
        findsOneWidget,
      );

      source.offline = false;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Issue 1'), findsOneWidget);
    });

    testWidgets('an undownloaded issue leads to the archive screen', (
      tester,
    ) async {
      await _pump(tester, const IssuesScreen(), db: await _seeded());
      await tester.tap(find.text('Issue 100'));
      await tester.pumpAndSettle();
      expect(find.text('Phrack archive'), findsOneWidget);
    });
  });

  group('issue screen', () {
    testWidgets('lists philes with title and author', (tester) async {
      await _pump(tester, const IssueScreen(issue: 99), db: await _seeded());

      expect(find.text('Introduction'), findsOneWidget);
      expect(find.text('Synthetic Staff'), findsOneWidget);
      // No author in the archive: no subtitle, nothing invented.
      final noAuthor = tester.widget<ListTile>(
        find.byKey(const ValueKey('phile-2')),
      );
      expect((noAuthor.title! as Text).data, 'Phile 2');
      expect(noAuthor.subtitle, isNull);
    });

    testWidgets('tapping a phile opens it in the reader from storage', (
      tester,
    ) async {
      await _pump(tester, const IssueScreen(issue: 99), db: await _seeded());

      await tester.tap(find.text('Phile 2'));
      await tester.pumpAndSettle();

      expect(find.byType(ReaderView), findsOneWidget);
      expect(find.text('╔══╗'), findsOneWidget);
      expect(find.byKey(const ValueKey('reader-title')), findsOneWidget);
    });

    testWidgets('back from the reader returns to the same scroll position', (
      tester,
    ) async {
      await _pump(tester, const IssueScreen(issue: 98), db: await _seeded());

      await tester.drag(find.byType(ListView), const Offset(0, -900));
      await tester.pumpAndSettle();
      final list = tester.state<ScrollableState>(find.byType(Scrollable));
      final offset = list.position.pixels;
      expect(offset, greaterThan(500));

      final visible = find.textContaining('Phile title').evaluate().first;
      final title = (visible.widget as Text).data!;
      await tester.tap(find.text(title));
      await tester.pumpAndSettle();
      expect(find.byType(ReaderView), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        tester.state<ScrollableState>(find.byType(Scrollable)).position.pixels,
        offset,
      );
    });
  });

  testWidgets('launch to a phile takes two taps', (tester) async {
    setSurface(tester, const Size(390, 844));
    addTearDown(tester.view.reset);
    final db = await _seeded();
    addTearDown(db.close);
    await tester.pumpWidget(
      ProviderScope(
        overrides: archiveOverrides(database: db),
        child: const AtdtApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Issue 99')); // 1
    await tester.pumpAndSettle();
    await tester.tap(find.text('Introduction')); // 2
    await tester.pumpAndSettle();

    expect(find.text('                    ==Phrack Inc.=='), findsOneWidget);
  });

  test('release dates format as calendar dates in UTC', () {
    expect(formatReleaseDate(DateTime.utc(2025, 8, 19)), '19 Aug 2025');
    // Midnight UTC is still the 17th, even when shown from UTC-6.
    expect(formatReleaseDate(DateTime.utc(1985, 11, 17)), '17 Nov 1985');
  });
}
