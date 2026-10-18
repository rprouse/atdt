// Visual record of the reader at fixed viewport sizes. Linux only: see
// tool/goldens/ for regenerating these on Windows or macOS via Docker.
import 'package:atdt/reader/reader_font.dart';
import 'package:atdt/reader/reader_theme.dart';
import 'package:atdt/search/search_query.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/reader_harness.dart';

const _sizes = {'portrait': Size(390, 844), 'landscape': Size(844, 390)};

void main() {
  setUpAll(loadReaderFonts);

  Future<void> expectGolden(
    WidgetTester tester, {
    required String fixtureName,
    required ReaderFont font,
    required Size size,
    required String name,
    ReaderTheme? theme,
  }) async {
    setSurface(tester, size);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      theme == null
          ? readerApp(text: fixture(fixtureName), font: font)
          : readerApp(
              text: fixture(fixtureName),
              font: font,
              background: theme.background,
              foreground: theme.foreground,
            ),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  for (final id in manifestFontIds) {
    for (final MapEntry(key: orientation, value: size) in _sizes.entries) {
      testWidgets(
        '80 columns at fit: $id $orientation',
        (tester) => expectGolden(
          tester,
          fixtureName: 'exact_80.txt',
          font: fontById(id),
          size: size,
          name: 'exact_80_${id}_$orientation',
        ),
        skip: !goldensSupported,
      );
    }

    testWidgets(
      'box drawing: $id',
      (tester) => expectGolden(
        tester,
        fixtureName: 'box_drawing.txt',
        font: fontById(id),
        size: _sizes['portrait']!,
        name: 'box_drawing_$id',
      ),
      skip: !goldensSupported,
    );
  }

  // The reader in every built-in theme (spec Stage F acceptance).
  for (final theme in builtInThemes) {
    testWidgets(
      'theme: ${theme.id}',
      (tester) => expectGolden(
        tester,
        fixtureName: 'box_drawing.txt',
        font: jetBrainsMono,
        size: _sizes['portrait']!,
        name: 'theme_${theme.id}',
        theme: theme,
      ),
      skip: !goldensSupported,
    );
  }

  // Characters a font lacks become its own placeholder, so the closing bar
  // on every line stays in the same column (spec Stage E acceptance).
  for (final id in manifestFontIds) {
    testWidgets(
      'missing glyphs keep columns aligned: $id',
      (tester) => expectGolden(
        tester,
        fixtureName: 'glyph_coverage.txt',
        font: fontById(id),
        size: _sizes['portrait']!,
        name: 'placeholders_$id',
      ),
      skip: !goldensSupported,
    );
  }

  // Search matches are marked without moving a column (spec Stage H).
  testWidgets('search matches are highlighted', (tester) async {
    setSurface(tester, _sizes['portrait']!);
    addTearDown(tester.view.reset);
    final theme = builtInThemes.first;
    await tester.pumpWidget(
      readerApp(
        text: fixture('tabs_code.txt'),
        font: jetBrainsMono,
        background: theme.background,
        foreground: theme.foreground,
        selection: theme.selection,
        highlight: SearchQuery.parse('int printf'),
      ),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/search_highlight.png'),
    );
  }, skip: !goldensSupported);

  testWidgets(
    'ligature-prone sequences render as separate characters',
    (tester) => expectGolden(
      tester,
      fixtureName: 'ligatures.txt',
      font: jetBrainsMono,
      size: _sizes['landscape']!,
      name: 'ligatures_jetbrains_mono',
    ),
    skip: !goldensSupported,
  );
}
