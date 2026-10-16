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

  for (final font in [jetBrainsMono, pxPlusVga]) {
    for (final MapEntry(key: orientation, value: size) in _sizes.entries) {
      testWidgets(
        '80 columns at fit: ${font.id} $orientation',
        (tester) => expectGolden(
          tester,
          fixtureName: 'exact_80.txt',
          font: font,
          size: size,
          name: 'exact_80_${font.id}_$orientation',
        ),
        skip: !goldensSupported,
      );
    }

    testWidgets(
      'box drawing: ${font.id}',
      (tester) => expectGolden(
        tester,
        fixtureName: 'box_drawing.txt',
        font: font,
        size: _sizes['portrait']!,
        name: 'box_drawing_${font.id}',
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
