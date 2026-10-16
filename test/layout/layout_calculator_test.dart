import 'package:atdt/layout/layout_calculator.dart';
import 'package:flutter_test/flutter_test.dart';

const _vector = MonoFontMetrics(advanceRatio: 0.6, lineHeightRatio: 1.2);

// An 8x16 bitmap-derived font whose native size is 16px.
const _pixel = MonoFontMetrics(
  advanceRatio: 0.5,
  lineHeightRatio: 1.0,
  integerScale: true,
  cellWidthPx: 8,
  nativeSizePx: 16,
);

ViewportMetrics _viewport({
  double width = 400,
  double safeLeft = 0,
  double safeRight = 0,
  double padding = 8,
  double dpr = 3,
}) => ViewportMetrics(
  logicalWidth: width,
  safeAreaLeft: safeLeft,
  safeAreaRight: safeRight,
  horizontalPadding: padding,
  devicePixelRatio: dpr,
);

void main() {
  group('vector fonts', () {
    test('fit font size shows exactly 80 columns in the available width', () {
      final layout = computeLayout(
        viewport: _viewport(width: 400, padding: 8),
        font: _vector,
        longestLineColumns: 80,
      );

      // availableWidth = 400 - 16 = 384; 384 / (80 * 0.6) = 8.0
      expect(layout.availableWidth, 384);
      expect(layout.fontSize, closeTo(8.0, 1e-9));
      expect(layout.glyphAdvance * 80, closeTo(384, 1e-9));
      expect(layout.textLeft, 8);
      expect(layout.integerScale, isNull);
      expect(layout.usedFallback, isFalse);
    });

    test('line height follows the font ratio, snapped to physical pixels', () {
      final layout = computeLayout(
        viewport: _viewport(width: 400, padding: 8, dpr: 3),
        font: _vector,
        longestLineColumns: 80,
      );

      // 8.0 * 1.2 = 9.6 logical = 28.8 physical -> 29 physical.
      expect(layout.lineHeight, closeTo(29 / 3, 1e-9));
    });

    test('uses the measured advance ratio, not an assumed 0.6', () {
      const narrow = MonoFontMetrics(advanceRatio: 0.5, lineHeightRatio: 1.2);
      final layout = computeLayout(
        viewport: _viewport(width: 400, padding: 0),
        font: narrow,
        longestLineColumns: 80,
      );

      expect(layout.fontSize, closeTo(10.0, 1e-9));
      expect(layout.glyphAdvance * 80, closeTo(400, 1e-9));
    });
  });

  group('safe areas', () {
    test('safe-area insets reduce the available width', () {
      final layout = computeLayout(
        viewport: _viewport(
          width: 900,
          safeLeft: 44,
          safeRight: 34,
          padding: 8,
        ),
        font: _vector,
        longestLineColumns: 80,
      );

      expect(layout.availableWidth, 900 - 44 - 34 - 16);
      expect(layout.textLeft, 44 + 8);
      expect(layout.glyphAdvance * 80, closeTo(806, 1e-9));
    });
  });

  group('integer-scaled pixel fonts', () {
    test('renders at the largest whole multiple of the native cell', () {
      // availableWidth 384 logical * dpr 3 = 1152 physical.
      // 1152 / (80 * 8) = 1.8 -> scale 1.
      final layout = computeLayout(
        viewport: _viewport(width: 400, padding: 8, dpr: 3),
        font: _pixel,
        longestLineColumns: 80,
      );

      expect(layout.integerScale, 1);
      expect(layout.fontSize, closeTo(16 / 3, 1e-9));
      expect(layout.usedFallback, isFalse);
    });

    test('picks a larger scale when there is room for it', () {
      // 900 - 16 = 884 logical * 3 = 2652 physical / 640 = 4.14 -> 4.
      final layout = computeLayout(
        viewport: _viewport(width: 900, padding: 8, dpr: 3),
        font: _pixel,
        longestLineColumns: 80,
      );

      expect(layout.integerScale, 4);
      expect(layout.fontSize, closeTo(4 * 16 / 3, 1e-9));
      // Each glyph is exactly 4 * 8 = 32 physical pixels wide.
      expect(layout.glyphAdvance * 3, closeTo(32, 1e-9));
    });

    test('centres the 80-column block on a whole physical pixel', () {
      final layout = computeLayout(
        viewport: _viewport(width: 900, padding: 8, dpr: 3),
        font: _pixel,
        longestLineColumns: 80,
      );

      // Block is 80 * 32 = 2560 physical; available 2652; spare 92 -> 46.
      // textLeft physical = 8 * 3 + 46 = 70.
      expect(layout.textLeft * 3, closeTo(70, 1e-9));
      expect(layout.blockWidth * 3, closeTo(2560, 1e-9));
    });

    test('snaps textLeft when the centring offset is fractional', () {
      // dpr 2.75: available (500 - 16) * 2.75 = 1331 physical; scale 2 ->
      // block 1280, spare 51, half 25.5 -> floor 25. Padding 8 * 2.75 = 22.
      final layout = computeLayout(
        viewport: _viewport(width: 500, padding: 8, dpr: 2.75),
        font: _pixel,
        longestLineColumns: 80,
      );

      expect(layout.integerScale, 2);
      final physicalLeft = layout.textLeft * 2.75;
      expect(physicalLeft, closeTo(physicalLeft.roundToDouble(), 1e-9));
      expect(physicalLeft, closeTo(47, 1e-9));
    });

    test('line height lands on whole physical pixels', () {
      final layout = computeLayout(
        viewport: _viewport(width: 500, padding: 8, dpr: 2.75),
        font: _pixel,
        longestLineColumns: 80,
      );

      final physical = layout.lineHeight * 2.75;
      expect(physical, closeTo(physical.roundToDouble(), 1e-9));
      expect(physical, closeTo(32, 1e-9));
    });

    test('falls back to fit size when even scale 1 does not fit', () {
      // 300 - 16 = 284 logical * 2 = 568 physical < 640.
      final layout = computeLayout(
        viewport: _viewport(width: 300, padding: 8, dpr: 2),
        font: _pixel,
        longestLineColumns: 80,
      );

      expect(layout.integerScale, isNull);
      expect(layout.usedFallback, isTrue);
      expect(layout.glyphAdvance * 80, closeTo(284, 1e-9));
      expect(layout.textLeft, 8);
    });
  });

  group('overflow content width', () {
    test('content is 80 columns wide for short files', () {
      final layout = computeLayout(
        viewport: _viewport(width: 400, padding: 8),
        font: _vector,
        longestLineColumns: 12,
      );

      expect(layout.contentColumns, 80);
      expect(layout.contentWidth, closeTo(384, 1e-9));
    });

    test('content widens to the longest line', () {
      final layout = computeLayout(
        viewport: _viewport(width: 400, padding: 8),
        font: _vector,
        longestLineColumns: 132,
      );

      expect(layout.contentColumns, 132);
      expect(layout.contentWidth, closeTo(132 * 4.8, 1e-9));
    });
  });

  group('invalid input', () {
    test('rejects viewports with no room for text', () {
      expect(
        () => computeLayout(
          viewport: _viewport(width: 10, padding: 8),
          font: _vector,
          longestLineColumns: 80,
        ),
        throwsArgumentError,
      );
    });

    test('rejects pixel-font metrics without cell sizes', () {
      expect(
        () => const MonoFontMetrics(
          advanceRatio: 0.5,
          lineHeightRatio: 1,
          integerScale: true,
        ).validate(),
        throwsArgumentError,
      );
    });
  });
}
