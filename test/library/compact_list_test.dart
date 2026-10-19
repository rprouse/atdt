// The issue and phile lists use half Material's gap between rows.
import 'package:atdt/archive/issue_import.dart';
import 'package:atdt/ingest/phile_text.dart';
import 'package:atdt/library/issue_screen.dart';
import 'package:atdt/library/issues_screen.dart';
import 'package:atdt/storage/archive_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/archive_harness.dart';
import '../helpers/reader_harness.dart';

Future<void> _pump(WidgetTester tester, ArchiveDatabase db, Widget home) async {
  setSurface(tester, const Size(390, 844));
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: archiveOverrides(database: db),
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: home),
    ),
  );
  await tester.pumpAndSettle();
}

double _height(WidgetTester tester, String key) =>
    tester.getSize(find.byKey(ValueKey(key))).height;

/// Row height less its title and subtitle: the space between rows' text.
double _gap(WidgetTester tester, String key) {
  final row = find.byKey(ValueKey(key));
  final lines = find.descendant(of: row, matching: find.byType(Text));
  final text = tester
      .widgetList<Text>(lines)
      .where((t) => !RegExp(r'^\s*\d+$').hasMatch(t.data ?? ''))
      .map((t) => tester.getSize(find.byWidget(t)).height)
      .fold(0.0, (a, b) => a + b);
  return _height(tester, key) - text;
}

void main() {
  setUpAll(loadReaderFonts);

  late ArchiveDatabase db;
  setUp(() async {
    db = memoryArchiveDatabase();
    await seedLibrary(db);
  });
  tearDown(() => db.close());

  testWidgets('issue rows: 14 dp between rows instead of 28', (tester) async {
    await _pump(tester, db, const IssuesScreen());
    // 7 dp above and below the text; Material's default leaves 28.
    expect(_gap(tester, 'issue-98'), 14);
    expect(_gap(tester, 'issue-100'), 14, reason: 'not downloaded');
  });

  testWidgets('phile rows likewise, never under 48 dp', (tester) async {
    await db.saveIssue(
      ImportedIssue(
        number: 97,
        sourceChecksum: 'test',
        philes: [
          ImportedPhile(
            number: 1,
            title: 'No author',
            text: PhileText.fromBytes('text\n'.codeUnits),
          ),
        ],
      ),
      fetchedAt: DateTime.utc(2026),
    );
    await _pump(tester, db, const IssueScreen(issue: 98));
    expect(_gap(tester, 'phile-1'), 14, reason: 'title and author');

    await _pump(tester, db, const IssueScreen(issue: 97));
    expect(_height(tester, 'phile-1'), 48, reason: 'title only');
  });
}
