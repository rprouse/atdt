// Stage H: indexing, the search screen, and jumping to a match.
import 'package:atdt/library/search_providers.dart';
import 'package:atdt/library/search_screen.dart';
import 'package:atdt/reader/reader_view.dart';
import 'package:atdt/storage/archive_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/archive_harness.dart';
import '../helpers/reader_harness.dart';

const _portrait = Size(390, 844);

/// Never finishes, so the progress banner stays up.
class _StuckIndexer extends SearchIndexer {
  @override
  SearchIndexStatus? build() => const SearchIndexStatus(indexed: 1, total: 4);
}

Future<ProviderContainer> _open(
  WidgetTester tester,
  ArchiveDatabase db, {
  List<Override> extra = const [],
  FakeArchiveSource? source,
}) async {
  setSurface(tester, _portrait);
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: [
      ...archiveOverrides(database: db, source: source),
      ...extra,
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SearchScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byKey(const ValueKey('search-field')), text);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
}

/// The text of every span painted with a background.
List<String?> _marked(InlineSpan root) {
  final marked = <String?>[];
  root.visitChildren((span) {
    if (span is TextSpan && span.style?.backgroundColor != null) {
      marked.add(span.text);
    }
    return true;
  });
  return marked;
}

String _summary(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('search-summary'))).data!;

void main() {
  setUpAll(loadReaderFonts);

  late ArchiveDatabase db;
  setUp(() => db = memoryArchiveDatabase());
  tearDown(() => db.close());

  testWidgets('stored philes are indexed without being asked', (tester) async {
    await seedLibrary(db);
    final container = await _open(tester, db);
    final status = container.read(searchIndexerProvider)!;
    expect((status.indexed, status.total, status.complete), (43, 43, true));
    expect(find.byKey(const ValueKey('index-progress')), findsNothing);
  });

  testWidgets('results are grouped by issue, newest first, with a '
      'highlighted snippet', (tester) async {
    await seedLibrary(db);
    await _open(tester, db);
    await _type(tester, 'phile');

    expect(_summary(tester), startsWith('41 philes, 41 lines · '));
    final h99 = tester.getTopLeft(
      find.byKey(const ValueKey('issue-header-99')),
    );
    final h98 = tester.getTopLeft(
      find.byKey(const ValueKey('issue-header-98')),
    );
    expect(h99.dy, lessThan(h98.dy));

    final id = (await db.phile(99, 1))!.id;
    final snippet = tester.widget<Text>(find.byKey(ValueKey('snippet-$id')));
    final spans = (snippet.textSpan! as TextSpan).children!.cast<TextSpan>();
    expect(
      spans.map((s) => s.text).join(),
      'Volume Nine, Issue 99, Phile 1 of 3',
    );
    expect(
      spans.where((s) => s.style?.backgroundColor != null).map((s) => s.text),
      ['Phile'],
    );
  });

  testWidgets('titles and authors only', (tester) async {
    await seedLibrary(db);
    await _open(tester, db);
    await _type(tester, 'synthetic');
    expect(find.text('No matches'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('titles-only')));
    await tester.pumpAndSettle();
    expect(_summary(tester), startsWith('1 phile · '));
    expect(find.text('Introduction'), findsOneWidget);
  });

  testWidgets('the issue range narrows results', (tester) async {
    await seedLibrary(db);
    await _open(tester, db);
    await _type(tester, 'phile');
    expect(find.byKey(const ValueKey('issue-header-98')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('issue-range')));
    await tester.pumpAndSettle();
    // Drag the lower thumb all the way up: issues 99 to 99.
    final slider = find.byKey(const ValueKey('issue-range-slider'));
    await tester.dragFrom(
      tester.getTopLeft(slider) + Offset(24, tester.getSize(slider).height / 2),
      Offset(tester.getSize(slider).width, 0),
    );
    await tester.tap(find.byKey(const ValueKey('issue-range-done')));
    await tester.pumpAndSettle();

    expect(find.text('Issues 99–99'), findsOneWidget);
    expect(find.byKey(const ValueKey('issue-header-98')), findsNothing);
    expect(_summary(tester), startsWith('1 phile, '));
  });

  testWidgets('search needs no network', (tester) async {
    await seedLibrary(db);
    await _open(tester, db, source: FakeArchiveSource([])..offline = true);
    await _type(tester, 'second');
    expect(_summary(tester), startsWith('40 philes, 40 lines · '));
  });

  testWidgets('progress shows while indexing is unfinished', (tester) async {
    await seedLibrary(db);
    await _open(
      tester,
      db,
      extra: [searchIndexerProvider.overrideWith(_StuckIndexer.new)],
    );
    expect(find.textContaining('Indexing 1 of 4 philes'), findsOneWidget);
  });

  group('opening a result', () {
    testWidgets('lands with the match visible below the chrome, '
        'highlighted', (tester) async {
      final id = await seedPhile(db, 'ten_thousand_lines.txt', title: 'Big');
      await _open(tester, db);
      await _type(tester, '04321');
      await tester.tap(find.byKey(ValueKey('hit-$id')));
      await tester.pumpAndSettle();

      final match = find.byKey(const ValueKey('match-4321'));
      expect(match, findsOneWidget);
      final row = tester.getRect(match);
      final chrome = tester.getRect(find.byKey(const ValueKey('chrome')));
      expect(row.top, greaterThan(chrome.bottom));
      expect(row.bottom, lessThan(_portrait.height));

      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: match, matching: find.byType(RichText)),
      );
      expect(_marked(paragraph.text), ['04321']);
    });

    testWidgets('the highlight moves no column', (tester) async {
      final id = await seedPhile(db, 'ten_thousand_lines.txt');
      await _open(tester, db);
      await _type(tester, 'shell');
      await tester.tap(find.byKey(ValueKey('hit-$id')));
      await tester.pumpAndSettle();

      final state = tester.state<ReaderViewState>(find.byType(ReaderView));
      final advance = state.layout!.glyphAdvance;
      final match = find
          .byWidgetPredicate(
            (w) =>
                w.key is ValueKey<String> &&
                (w.key! as ValueKey<String>).value.startsWith('match-'),
          )
          .first;
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: match, matching: find.byType(RichText)),
      );
      final text = paragraph.text.toPlainText();
      final start = text.indexOf('shell');
      // Every character, marked or not, sits on the 80-column grid.
      for (final i in [0, start, start + 5, text.length - 1]) {
        final box = paragraph
            .getBoxesForSelection(
              TextSelection(baseOffset: i, extentOffset: i + 1),
            )
            .single;
        expect(box.left, closeTo(i * advance, 0.01), reason: 'column $i');
      }
    });
  });
}
