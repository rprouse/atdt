// Visual record of the reader at fixed viewport sizes. Linux only: see
// tool/goldens/ for regenerating these on Windows or macOS via Docker.
import 'package:atdt/reader/reader_font.dart';
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
  }) async {
    setSurface(tester, size);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(readerApp(text: fixture(fixtureName), font: font));
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
