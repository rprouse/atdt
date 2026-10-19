// Stage I: the jump list in the reader chrome.
import 'dart:convert';

import 'package:atdt/archive/issue_import.dart';
import 'package:atdt/ingest/phile_text.dart';
import 'package:atdt/reader/reader_screen.dart';
import 'package:atdt/reader/reader_view.dart';
import 'package:atdt/storage/archive_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/archive_harness.dart';
import '../helpers/reader_harness.dart';

/// Headings every 300 lines: 1 at line 2, 1.1 at 303, 2 at 604.
String _sectioned() {
  final b = StringBuffer('Synthetic phile\n\n');
  for (final heading in [
    '--[ 1 - Introduction',
    '----[ 1.1 - Background',
    '--[ 2 - The method',
  ]) {
    b.writeln(heading);
    for (var i = 0; i < 300; i++) {
      b.writeln('body $i');
    }
  }
  return b.toString();
}

Future<int> _store(ArchiveDatabase db, String text) async {
  await db.saveIssue(
    ImportedIssue(
      number: 70,
      sourceChecksum: 'test',
      philes: [
        ImportedPhile(
          number: 1,
          title: 'Sectioned',
          text: PhileText.fromBytes(utf8.encode(text)),
        ),
      ],
    ),
    fetchedAt: DateTime.utc(2026),
  );
  return (await db.phile(70, 1))!.id;
}

Future<void> _open(WidgetTester tester, ArchiveDatabase db, int id) async {
  setSurface(tester, const Size(390, 844));
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: archiveOverrides(database: db),
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: ReaderScreen(phileId: id)),
    ),
  );
  await tester.pumpAndSettle();
}

ReaderViewState _reader(WidgetTester tester) =>
    tester.state<ReaderViewState>(find.byType(ReaderView));

bool _chromeVisible(WidgetTester tester) => !tester
    .widget<IgnorePointer>(find.byKey(const ValueKey('chrome-gate')))
    .ignoring;

void main() {
  setUpAll(loadReaderFonts);

  late ArchiveDatabase db;
  setUp(() => db = memoryArchiveDatabase());
  tearDown(() => db.close());

  testWidgets('no jump list when no sections were found', (tester) async {
    final id = await seedPhile(db, 'tabs_code.txt');
    await _open(tester, db, id);
    expect(find.byKey(const ValueKey('sections')), findsNothing);
  });

  testWidgets('a section jumps to its heading, with the chrome out of the '
      'way', (tester) async {
    final id = await _store(db, _sectioned());
    await _open(tester, db, id);

    await tester.tap(find.byKey(const ValueKey('sections')));
    await tester.pumpAndSettle();
    expect(find.text('1  Introduction'), findsOneWidget);
    expect(find.text('1.1  Background'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('section-604')));
    await tester.pumpAndSettle();

    expect(_reader(tester).position.topLineIndex, 604);
    expect(_reader(tester).position.fractionIntoLine, closeTo(0, 1e-6));
    expect(_chromeVisible(tester), isFalse);
    expect(find.text('--[ 2 - The method'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('--[ 2 - The method')).dy,
      readerTopInset,
    );
  });

  testWidgets('the list marks the section being read', (tester) async {
    final id = await _store(db, _sectioned());
    await _open(tester, db, id);
    final layout = _reader(tester).layout!;
    _reader(tester).verticalController!.jumpTo(400 * layout.lineHeight);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('sections')));
    await tester.pumpAndSettle();
    bool selected(int line) =>
        tester.widget<ListTile>(find.byKey(ValueKey('section-$line'))).selected;
    expect([selected(2), selected(303), selected(604)], [false, true, false]);
  });
}
