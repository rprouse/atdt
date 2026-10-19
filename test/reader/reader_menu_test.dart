// The reader's top bar: back, title, progress and one menu holding the
// rest (owner tweak, 2026-10-19).
import 'package:atdt/reader/reader_screen.dart';
import 'package:atdt/reader/reader_settings.dart';
import 'package:atdt/storage/archive_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/archive_harness.dart';
import '../helpers/reader_harness.dart';

void main() {
  setUpAll(loadReaderFonts);

  late ArchiveDatabase db;
  late ProviderContainer container;

  setUp(() => db = memoryArchiveDatabase());
  tearDown(() => db.close());

  Future<void> open(WidgetTester tester) async {
    setSurface(tester, const Size(390, 844));
    addTearDown(tester.view.reset);
    final id = await seedPhile(
      db,
      'ten_thousand_lines.txt',
      title: 'A long phile title that used to be cut short by five icons',
    );
    container = ProviderContainer(overrides: archiveOverrides(database: db));
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: ReaderScreen(phileId: id)),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String submenu, String item) async {
    await tester.tap(find.byKey(const ValueKey('reader-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey(submenu)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey(item)));
    await tester.pumpAndSettle();
  }

  final chrome = find.byKey(const ValueKey('chrome'));

  testWidgets('the bar holds back, title, progress and the menu', (
    tester,
  ) async {
    await open(tester);
    expect(
      find.descendant(of: chrome, matching: find.byType(IconButton)),
      findsNWidgets(2),
    );
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.byTooltip('Menu'), findsOneWidget);
    // The title gets everything but back, progress and menu.
    final title = tester.getSize(find.byKey(const ValueKey('reader-title')));
    expect(title.width, greaterThan(390 - 3 * 48 - 60));
  });

  testWidgets('font, theme and orientation are chosen from submenus', (
    tester,
  ) async {
    await open(tester);
    await choose(tester, 'menu-font', 'menu-font-terminus');
    await choose(tester, 'menu-theme', 'menu-theme-amber_phosphor');
    await choose(tester, 'menu-orientation', 'menu-orientation-landscape');

    final settings = container.read(readerSettingsProvider);
    expect(settings.fontId, 'terminus');
    expect(settings.themeId, 'amber_phosphor');
    expect(settings.orientation, OrientationMode.landscape);
  });

  testWidgets('the current choice is ticked', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('reader-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-theme')));
    await tester.pumpAndSettle();
    final current = container.read(currentThemeProvider).id;
    expect(
      find.descendant(
        of: find.byKey(ValueKey('menu-theme-$current')),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.check), findsOneWidget);
  });

  testWidgets('the debug overlay toggles from the menu', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('reader-menu')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu-debug')));
    await tester.pumpAndSettle();
    expect(container.read(readerSettingsProvider).showDebugOverlay, isTrue);
    expect(find.byKey(const ValueKey('debug-overlay')), findsOneWidget);
  });
}
