import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:atdt/reader/reader_screen.dart';
import 'package:atdt/reader/reader_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/archive_harness.dart';

import '../helpers/reader_harness.dart';

final _firstLine = find.textContaining(RegExp('^00000 '));
final _tenthLine = find.textContaining(RegExp('^00010 '));

/// Where text sits: a line's corner, a later line's corner (catches line
/// height changes) and the right edge of the glyphs (catches font size).
(Offset, Offset, double) _textGeometry(WidgetTester tester) {
  final line = tester.widget<Text>(_tenthLine).data!;
  return (
    tester.getTopLeft(_firstLine),
    tester.getTopLeft(_tenthLine),
    glyphExtent(tester, line).right,
  );
}

bool _chromeVisible(WidgetTester tester) => !tester
    .widget<IgnorePointer>(find.byKey(const ValueKey('chrome-gate')))
    .ignoring;

void main() {
  setUpAll(loadReaderFonts);

  late List<String> uiModes;

  Future<void> openApp(
    WidgetTester tester, {
    Size size = const Size(390, 844),
  }) async {
    setSurface(tester, size);
    addTearDown(tester.view.reset);
    uiModes = [];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setEnabledSystemUIMode') {
          uiModes.add(call.arguments as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final db = memoryArchiveDatabase();
    addTearDown(db.close);
    final id = await seedPhile(db, 'ten_thousand_lines.txt', title: 'Big');
    await tester.pumpWidget(
      ProviderScope(
        overrides: archiveOverrides(database: db),
        child: MaterialApp(home: ReaderScreen(phileId: id)),
      ),
    );
    await tester.pumpAndSettle();
    expect(_firstLine, findsOneWidget, reason: 'the stored phile is open');
  }

  testWidgets('tap toggles the chrome without moving any line', (tester) async {
    await openApp(tester);
    expect(_chromeVisible(tester), isTrue);
    final before = _textGeometry(tester);

    await tester.tapAt(const Offset(195, 500));
    await tester.pumpAndSettle();
    expect(_chromeVisible(tester), isFalse);
    expect(_textGeometry(tester), before);
    expect(uiModes.last, 'SystemUiMode.immersiveSticky');

    await tester.tapAt(const Offset(195, 500));
    await tester.pumpAndSettle();
    expect(_chromeVisible(tester), isTrue);
    expect(_textGeometry(tester), before);
    expect(uiModes.last, 'SystemUiMode.edgeToEdge');
  });

  testWidgets('scrolling down hides the chrome, scrolling up reveals it', (
    tester,
  ) async {
    await openApp(tester);

    await tester.drag(find.byType(ListView), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(_chromeVisible(tester), isFalse);

    await tester.drag(find.byType(ListView), const Offset(0, 100));
    await tester.pumpAndSettle();
    expect(_chromeVisible(tester), isTrue);
  });

  testWidgets('system bars appearing do not move the text', (tester) async {
    // Landscape with a 3-button nav bar on the right and a status bar: the
    // insets immersive mode removes when the chrome hides.
    await openApp(tester, size: const Size(844, 390));
    final before = _textGeometry(tester);

    tester.view
      ..padding = const FakeViewPadding(top: 24 * 3, right: 48 * 3)
      ..viewPadding = const FakeViewPadding(top: 24 * 3, right: 48 * 3);
    await tester.pumpAndSettle();

    expect(_textGeometry(tester), before);
  });

  testWidgets('a side cutout in landscape insets the text', (tester) async {
    await openApp(tester, size: const Size(844, 390));
    final before = _textGeometry(tester);

    tester.view.displayFeatures = [
      const DisplayFeature(
        // Display feature bounds are logical pixels, unlike view padding.
        bounds: Rect.fromLTWH(0, 150, 30, 90),
        type: DisplayFeatureType.cutout,
        state: DisplayFeatureState.unknown,
      ),
    ];
    await tester.pumpAndSettle();

    expect(_textGeometry(tester).$1.dx, closeTo(before.$1.dx + 30, 0.01));
  });

  group('folds and hinges', () {
    // A book-style device, open: 900 wide, a vertical feature at 440-460.
    const size = Size(900, 700);
    DisplayFeature feature(
      DisplayFeatureType type,
      DisplayFeatureState state,
    ) => DisplayFeature(
      bounds: const Rect.fromLTWH(440, 0, 20, 700),
      type: type,
      state: state,
    );

    double rightEdge(WidgetTester tester) =>
        glyphExtent(tester, tester.widget<Text>(_tenthLine).data!).right;

    testWidgets('a hinge keeps all 80 columns in one pane', (tester) async {
      await openApp(tester, size: size);
      tester.view.displayFeatures = [
        feature(DisplayFeatureType.hinge, DisplayFeatureState.unknown),
      ];
      await tester.pumpAndSettle();
      expect(rightEdge(tester), lessThanOrEqualTo(440));
      expect(tester.getTopLeft(_firstLine).dx, lessThan(440));
    });

    testWidgets('so does a half-open fold', (tester) async {
      await openApp(tester, size: size);
      tester.view.displayFeatures = [
        feature(DisplayFeatureType.fold, DisplayFeatureState.postureHalfOpened),
      ];
      await tester.pumpAndSettle();
      expect(rightEdge(tester), lessThanOrEqualTo(440));
    });

    testWidgets('a fold lying flat keeps the full width', (tester) async {
      await openApp(tester, size: size);
      final before = rightEdge(tester);
      tester.view.displayFeatures = [
        feature(DisplayFeatureType.fold, DisplayFeatureState.postureFlat),
      ];
      await tester.pumpAndSettle();
      expect(rightEdge(tester), closeTo(before, 0.01));
      expect(before, greaterThan(460));
    });

    testWidgets('the larger pane wins', (tester) async {
      await openApp(tester, size: size);
      tester.view.displayFeatures = [
        const DisplayFeature(
          bounds: Rect.fromLTWH(300, 0, 20, 700),
          type: DisplayFeatureType.hinge,
          state: DisplayFeatureState.unknown,
        ),
      ];
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(_firstLine).dx, greaterThanOrEqualTo(320));
    });
  });

  group('coverage notice', () {
    Future<ProviderContainer> openPhile(
      WidgetTester tester,
      String fixtureName,
    ) async {
      setSurface(tester, const Size(390, 844));
      addTearDown(tester.view.reset);
      final db = memoryArchiveDatabase();
      addTearDown(db.close);
      final id = await seedPhile(db, fixtureName);
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
      return container;
    }

    final notice = find.byKey(const ValueKey('coverage-notice'));

    testWidgets('offers a font that can draw every character', (tester) async {
      final container = await openPhile(tester, 'glyph_coverage.txt');

      // The default font lacks some; the first manifest font with all of
      // them is offered.
      expect(notice, findsOneWidget);
      expect(
        find.textContaining('JetBrains Mono has no glyph'),
        findsOneWidget,
      );
      final offer = testFonts.firstCovering(
        fixture('glyph_coverage.txt').inventory,
      )!;
      await tester.tap(find.text('Use ${offer.displayName}'));
      await tester.pumpAndSettle();

      expect(container.read(currentFontProvider), offer);
      expect(notice, findsNothing);
      expect(find.text('☺☻♥♦♣♠•◘○◙A|'), findsOneWidget);
    });

    testWidgets('dismissing it leaves every line where it was', (tester) async {
      await openPhile(tester, 'glyph_coverage.txt');
      final line = find.text('0123456789A|');
      final before = tester.getTopLeft(line);

      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();

      expect(notice, findsNothing);
      expect(tester.getTopLeft(line), before);
    });

    testWidgets('is not shown when the font covers the phile', (tester) async {
      await openPhile(tester, 'ten_thousand_lines.txt');
      expect(notice, findsNothing);
    });
  });
}
