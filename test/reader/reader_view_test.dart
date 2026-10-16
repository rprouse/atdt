import 'package:atdt/layout/layout_calculator.dart';
import 'package:atdt/reader/reader_font.dart';
import 'package:atdt/reader/reader_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/reader_harness.dart';

const _portrait = Size(390, 844);
const _landscape = Size(844, 390);

void main() {
  setUpAll(loadReaderFonts);

  group('fit to 80 columns', () {
    for (final size in [_portrait, _landscape]) {
      final orientation = size == _portrait ? 'portrait' : 'landscape';

      for (final font in readerFonts) {
        testWidgets('${font.id} fills the width in $orientation', (
          tester,
        ) async {
          setSurface(tester, size);
          addTearDown(tester.view.reset);
          final text = fixture('exact_80.txt');
          await tester.pumpWidget(readerApp(text: text, font: font));

          final line = text.lines[1];
          expect(line, hasLength(80));
          final extent = glyphExtent(tester, line);
          expect(extent.left, closeTo(readerHorizontalPadding, 0.01));

          // Text backends may round small-size advances (FreeType on Linux
          // lands up to ~0.7 px short over 80 glyphs; Windows is exact). The
          // spec's requirement is that all 80 columns are visible and there
          // is no room for an 81st, so assert that, not sub-pixel equality.
          final advance = (extent.right - extent.left) / 80;
          final textRight = size.width - readerHorizontalPadding;
          expect(extent.right, lessThanOrEqualTo(textRight + 0.01));
          expect(textRight - extent.right, lessThan(advance / 4));
          expect(extent.right, lessThanOrEqualTo(size.width));
        });
      }
    }

    testWidgets('measured advance ratios match the font files', (tester) async {
      expect(measureAdvanceRatio(jetBrainsMono), closeTo(0.6, 1e-4));
      expect(measureAdvanceRatio(bigBlueTerminal), closeTo(2 / 3, 1e-4));
      expect(measureAdvanceRatio(c64ProMono), closeTo(1, 1e-4));
    });
  });

  group('horizontal overflow', () {
    testWidgets('a 132-column line scrolls and every line moves with it', (
      tester,
    ) async {
      setSurface(tester, _portrait);
      addTearDown(tester.view.reset);
      final key = GlobalKey<ReaderViewState>();
      final text = fixture('widths_79_132.txt');
      await tester.pumpWidget(
        readerApp(text: text, font: jetBrainsMono, key: key),
      );

      final first = text.lines.first;
      final longest = text.lines[3];
      expect(longest, hasLength(132));
      final before = (
        glyphExtent(tester, first).left,
        glyphExtent(tester, longest).left,
      );

      await tester.drag(find.text(first), const Offset(-150, 0));
      await tester.pumpAndSettle();

      final after = (
        glyphExtent(tester, first).left,
        glyphExtent(tester, longest).left,
      );
      final shiftFirst = before.$1 - after.$1;
      final shiftLongest = before.$2 - after.$2;
      expect(shiftFirst, greaterThan(50));
      expect(shiftLongest, closeTo(shiftFirst, 1e-6));
      expect(key.currentState!.position.columnOffset, greaterThan(0));
    });

    testWidgets('an 80-column file does not scroll sideways', (tester) async {
      setSurface(tester, _portrait);
      addTearDown(tester.view.reset);
      final key = GlobalKey<ReaderViewState>();
      final text = fixture('exact_80.txt');
      await tester.pumpWidget(
        readerApp(text: text, font: jetBrainsMono, key: key),
      );

      await tester.drag(find.text(text.lines[1]), const Offset(-150, 0));
      await tester.pumpAndSettle();

      expect(key.currentState!.horizontalController!.offset, 0);
    });
  });

  group('position across metrics changes', () {
    Future<GlobalKey<ReaderViewState>> openLargeFile(
      WidgetTester tester,
      ReaderFont font,
    ) async {
      setSurface(tester, _portrait);
      final key = GlobalKey<ReaderViewState>();
      await tester.pumpWidget(
        readerApp(
          text: fixture('ten_thousand_lines.txt'),
          font: font,
          key: key,
        ),
      );
      return key;
    }

    void scrollTo(ReaderViewState state, int line, double columns) {
      final layout = state.layout!;
      state.verticalController!.jumpTo((line + 0.4) * layout.lineHeight);
      state.horizontalController!.jumpTo(columns * layout.glyphAdvance);
    }

    for (final font in readerFonts) {
      testWidgets('rotation keeps top line and column (${font.id})', (
        tester,
      ) async {
        final key = await openLargeFile(tester, font);
        addTearDown(tester.view.reset);
        final state = key.currentState!;
        scrollTo(state, 4321, 17);
        await tester.pump();
        final before = state.position;
        expect(before.topLineIndex, 4321);

        for (final size in [_landscape, _portrait, _landscape]) {
          setSurface(tester, size);
          await tester.pump();
          await tester.pump();

          final after = key.currentState!.position;
          expect(after.topLineIndex, before.topLineIndex, reason: '$size');
          expect(after.columnOffset, closeTo(before.columnOffset, 1e-6));
          // The new controllers really are at the restored offset.
          final layout = key.currentState!.layout!;
          expect(
            key.currentState!.verticalController!.offset,
            closeTo(before.verticalOffset(layout.lineHeight), 1e-6),
          );
          expect(
            find.textContaining(RegExp('^04321 ')),
            findsOneWidget,
            reason: 'line 4321 is built at $size',
          );
        }
      });
    }

    testWidgets('switching fonts mid-file keeps the top line', (tester) async {
      final key = await openLargeFile(tester, jetBrainsMono);
      addTearDown(tester.view.reset);
      scrollTo(key.currentState!, 7000, 0);
      await tester.pump();

      await tester.pumpWidget(
        readerApp(
          text: tester.widget<ReaderView>(find.byType(ReaderView)).text,
          font: bigBlueTerminal,
          key: key,
        ),
      );
      await tester.pump();

      expect(key.currentState!.position.topLineIndex, 7000);
      expect(key.currentState!.widget.font, bigBlueTerminal);
    });
  });

  group('ligatures', () {
    // Render '->' as one run with the reader's features, and as two glyphs
    // laid side by side. If calt is really off, the pixels are identical.
    // The control case (calt on) proves the comparison can see a ligature.
    Future<bool> rendersAsSeparateGlyphs(
      WidgetTester tester,
      String pair, {
      required List<FontFeature> features,
    }) async {
      const fontSize = 40.0;
      final advance = fontSize * measureAdvanceRatio(jetBrainsMono);
      TextStyle style(List<FontFeature> f) => TextStyle(
        fontFamily: jetBrainsMono.family,
        fontSize: fontSize,
        height: 1,
        color: const Color(0xFF000000),
        fontFeatures: f,
      );
      final joined = GlobalKey();
      final split = GlobalKey();
      Widget box(GlobalKey key, Widget child) => RepaintBoundary(
        key: key,
        child: ColoredBox(
          color: const Color(0xFFFFFFFF),
          child: SizedBox(
            width: advance * pair.length,
            height: fontSize,
            child: child,
          ),
        ),
      );

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              box(joined, Text(pair, style: style(features))),
              box(
                split,
                Stack(
                  children: [
                    for (var i = 0; i < pair.length; i++)
                      Positioned(
                        left: i * advance,
                        top: 0,
                        child: Text(pair[i], style: style(readerFontFeatures)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

      Future<List<int>> pixels(GlobalKey key) async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final data = await image.toByteData();
        image.dispose();
        return data!.buffer.asUint8List();
      }

      final result = await tester.runAsync(() async {
        final a = await pixels(joined);
        final b = await pixels(split);
        return listEquals(a, b);
      });
      return result!;
    }

    for (final pair in ['->', '!=', '==', '<=', 'www']) {
      testWidgets('"$pair" renders as separate characters', (tester) async {
        expect(
          await rendersAsSeparateGlyphs(
            tester,
            pair,
            features: readerFontFeatures,
          ),
          isTrue,
        );
      });
    }

    testWidgets('control: with calt on, "->" is a ligature', (tester) async {
      expect(
        await rendersAsSeparateGlyphs(tester, '->', features: const []),
        isFalse,
      );
    });
  });

  test('fitColumns is 80', () => expect(fitColumns, 80));
}
