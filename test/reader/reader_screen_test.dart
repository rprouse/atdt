import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:atdt/app.dart';
import 'package:atdt/reader/about.dart';
import 'package:atdt/reader/reader_font.dart';
import 'package:atdt/reader/reader_settings.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
    // Pin the document: the default depends on what is in assets/dev/.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentDocumentPathProvider.overrideWith(
            (ref) async => 'test/fixtures/ten_thousand_lines.txt',
          ),
        ],
        child: const AtdtApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(_firstLine, findsOneWidget, reason: 'default fixture is open');
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

  testWidgets('About lists a credit for every font', (tester) async {
    await openApp(tester);

    await tester.tap(find.byTooltip('About'));
    await tester.pumpAndSettle();

    for (final font in readerFonts) {
      expect(find.byKey(ValueKey('credit-${font.id}')), findsOneWidget);
    }
    expect(find.textContaining('not affiliated with Phrack'), findsOneWidget);
  });

  testWidgets('font licences are registered with their shipped text', (
    tester,
  ) async {
    LicenseRegistry.reset();
    addTearDown(LicenseRegistry.reset);
    registerFontLicences();

    final entries = await tester.runAsync(
      () => LicenseRegistry.licenses.toList(),
    );
    final byPackage = {
      for (final e in entries!)
        e.packages.single: e.paragraphs.map((p) => p.text).join(' '),
    };

    expect(byPackage['JetBrains Mono (font)'], contains('SIL Open Font'));
    expect(
      byPackage['BigBlue Terminal (font)'],
      contains('Attribution-ShareAlike 4.0'),
    );
    expect(
      byPackage['C64 Pro Mono (font)'],
      contains('freely provided to end users'),
    );
  });
}
