// Stage K: library screens are fully accessible to screen readers, meet
// Android and iOS tap-target sizes and text contrast, and survive large
// system text. The reader's size is governed by the 80-column rule, so it
// is checked for semantics, not scaling.
import 'package:atdt/download/download_screen.dart';
import 'package:atdt/library/issue_screen.dart';
import 'package:atdt/library/issues_screen.dart';
import 'package:atdt/library/search_screen.dart';
import 'package:atdt/reader/reader_screen.dart';
import 'package:atdt/reader/reader_theme.dart';
import 'package:atdt/settings/credits_screen.dart';
import 'package:atdt/settings/settings_screen.dart';
import 'package:atdt/settings/theme_editor_screen.dart';
import 'package:atdt/storage/archive_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/archive_harness.dart';
import 'helpers/reader_harness.dart';

typedef _Screen = ({
  String name,
  Widget Function() build,
  Future<void> Function(WidgetTester tester)? then,
});

final _screens = <_Screen>[
  (name: 'library', build: () => const IssuesScreen(), then: null),
  (name: 'issue', build: () => const IssueScreen(issue: 99), then: null),
  (
    name: 'search results',
    build: () => const SearchScreen(),
    then: (tester) async {
      await tester.enterText(find.byType(TextField), 'phile');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
    },
  ),
  (name: 'settings', build: () => const SettingsScreen(), then: null),
  (name: 'archive', build: () => const DownloadScreen(), then: null),
  (name: 'credits', build: () => const CreditsScreen(), then: null),
  (
    name: 'theme editor',
    build: () => ThemeEditorScreen(base: builtInThemes.first),
    then: null,
  ),
];

Future<void> _pump(
  WidgetTester tester,
  ArchiveDatabase db,
  _Screen screen, {
  ReaderTheme? theme,
  Size size = const Size(390, 844),
  double textScale = 1,
}) async {
  setSurface(tester, size);
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: archiveOverrides(database: db),
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: (theme ?? builtInThemes.first).toThemeData(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: screen.build(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await screen.then?.call(tester);
}

void main() {
  setUpAll(loadReaderFonts);

  late ArchiveDatabase db;
  setUp(() async {
    db = memoryArchiveDatabase();
    await seedLibrary(db);
  });
  tearDown(() => db.close());

  for (final screen in _screens) {
    group(screen.name, () {
      testWidgets('meets tap-target, label and contrast guidelines', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await _pump(tester, db, screen);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        semantics.dispose();
      });

      for (final scale in [2.0, 3.0]) {
        testWidgets('lays out at ${scale}x text on a small phone', (
          tester,
        ) async {
          await _pump(
            tester,
            db,
            screen,
            size: const Size(360, 640),
            textScale: scale,
          );
          expect(tester.takeException(), isNull);
        });
      }
    });
  }

  for (final theme in builtInThemes.skip(1)) {
    testWidgets('text contrast in the ${theme.id} theme', (tester) async {
      final semantics = tester.ensureSemantics();
      for (final screen in _screens.take(4)) {
        await _pump(tester, db, screen, theme: theme);
        await expectLater(
          tester,
          meetsGuideline(textContrastGuideline),
          reason: screen.name,
        );
      }
      semantics.dispose();
    });
  }

  testWidgets('the reader exposes each line to screen readers', (tester) async {
    final semantics = tester.ensureSemantics();
    final id = (await db.phile(98, 1))!.id;
    await _pump(tester, db, (
      name: 'reader',
      build: () => ReaderScreen(phileId: id),
      then: null,
    ));
    expect(find.bySemanticsLabel('phile 1'), findsOneWidget);
    expect(find.bySemanticsLabel('second line'), findsOneWidget);
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  group('reader chrome', () {
    bool chromeVisible(WidgetTester tester) => !tester
        .widget<IgnorePointer>(find.byKey(const ValueKey('chrome-gate')))
        .ignoring;

    Future<void> openReader(
      WidgetTester tester, {
      required bool screenReader,
    }) async {
      final id = (await db.phile(98, 1))!.id;
      setSurface(tester, const Size(390, 844));
      addTearDown(tester.view.reset);
      final container = ProviderContainer(
        overrides: archiveOverrides(database: db),
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(accessibleNavigation: screenReader),
              child: child!,
            ),
            home: ReaderScreen(phileId: id),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('stays with a screen reader running', (tester) async {
      await openReader(tester, screenReader: true);
      await tester.tapAt(const Offset(200, 600));
      await tester.pumpAndSettle();
      expect(chromeVisible(tester), isTrue);
    });

    testWidgets('once hidden, is gone from the semantics tree', (tester) async {
      final semantics = tester.ensureSemantics();
      await openReader(tester, screenReader: false);
      expect(_semanticsLabels(tester), contains('Back'));

      await tester.tapAt(const Offset(200, 600));
      await tester.pumpAndSettle();
      expect(chromeVisible(tester), isFalse);
      expect(_semanticsLabels(tester), isNot(contains('Back')));
      semantics.dispose();
    });
  });
}

/// Every label in the semantics tree a screen reader would see.
Set<String> _semanticsLabels(WidgetTester tester) {
  final labels = <String>{};
  bool visit(SemanticsNode node) {
    if (node.label.isNotEmpty) labels.add(node.label);
    node.visitChildren(visit);
    return true;
  }

  final view = tester.binding.renderViews.first;
  visit(view.owner!.semanticsOwner!.rootSemanticsNode!);
  return labels;
}
