/// Pure layout maths for the 80-column reader.
///
/// No Flutter imports: everything here is unit-testable on the plain Dart VM.
/// See "Core rendering rules" in docs/atdt-initial-spec.md.
library;

import 'dart:math' as math;

/// Columns visible at fit, whatever the font.
const int fitColumns = 80;

// Guards floor() against values like 69.9999999 that are really 70.
const double _epsilon = 1e-6;

/// Viewport inputs, in logical pixels.
class ViewportMetrics {
  const ViewportMetrics({
    required this.logicalWidth,
    required this.devicePixelRatio,
    this.safeAreaLeft = 0,
    this.safeAreaRight = 0,
    this.horizontalPadding = 0,
  });

  final double logicalWidth;
  final double devicePixelRatio;
  final double safeAreaLeft;
  final double safeAreaRight;
  final double horizontalPadding;

  double get availableWidth =>
      logicalWidth - safeAreaLeft - safeAreaRight - 2 * horizontalPadding;
}

/// Per-font metrics. [advanceRatio] must be measured, never assumed.
class MonoFontMetrics {
  const MonoFontMetrics({
    required this.advanceRatio,
    required this.lineHeightRatio,
    this.integerScale = false,
    this.cellWidthPx,
    this.nativeSizePx,
  });

  /// Glyph advance divided by font size.
  final double advanceRatio;

  /// Line height divided by font size.
  final double lineHeightRatio;

  /// Bitmap-derived font that must render at whole multiples of its cell.
  final bool integerScale;

  /// Native glyph cell width in pixels (pixel fonts only).
  final int? cellWidthPx;

  /// Font size at which one font pixel is one device pixel (pixel fonts only).
  final int? nativeSizePx;

  void validate() {
    if (advanceRatio <= 0 || lineHeightRatio <= 0) {
      throw ArgumentError('Font ratios must be positive');
    }
    if (integerScale && ((cellWidthPx ?? 0) <= 0 || (nativeSizePx ?? 0) <= 0)) {
      throw ArgumentError(
        'Integer-scaled fonts need cellWidthPx and nativeSizePx',
      );
    }
  }
}

/// Result of a layout pass. All lengths are logical pixels.
class ReaderLayout {
  const ReaderLayout({
    required this.availableWidth,
    required this.fontSize,
    required this.glyphAdvance,
    required this.lineHeight,
    required this.textLeft,
    required this.contentColumns,
    required this.devicePixelRatio,
    this.integerScale,
    this.usedFallback = false,
  });

  final double availableWidth;
  final double fontSize;
  final double glyphAdvance;
  final double lineHeight;

  /// Left edge of column 1, measured from the viewport's left edge.
  final double textLeft;

  /// max(80, longest line).
  final int contentColumns;
  final double devicePixelRatio;

  /// Whole-number scale for pixel fonts; null for vector fonts or fallback.
  final int? integerScale;

  /// A pixel font could not fit at scale 1 and fell back to fit size.
  final bool usedFallback;

  /// Width of the 80 columns visible at fit.
  double get blockWidth => fitColumns * glyphAdvance;

  /// Width of the whole text block, including overflow columns.
  double get contentWidth => contentColumns * glyphAdvance;
}

/// Computes font size, line height and text placement for one viewport.
///
/// Throws [ArgumentError] if the viewport leaves no room for text; callers
/// should skip layout until the viewport has a real size.
ReaderLayout computeLayout({
  required ViewportMetrics viewport,
  required MonoFontMetrics font,
  required int longestLineColumns,
}) {
  font.validate();
  final available = viewport.availableWidth;
  final dpr = viewport.devicePixelRatio;
  if (available <= 0 || dpr <= 0) {
    throw ArgumentError('Viewport has no room for text: $available, $dpr');
  }

  final contentColumns = math.max(fitColumns, longestLineColumns);
  final leftInset = viewport.safeAreaLeft + viewport.horizontalPadding;

  if (font.integerScale) {
    final physicalWidth = available * dpr;
    final cellWidth = font.cellWidthPx!;
    final scale = (physicalWidth / (fitColumns * cellWidth) + _epsilon).floor();
    if (scale >= 1) {
      final fontSize = scale * font.nativeSizePx! / dpr;
      final glyphAdvance = fontSize * font.advanceRatio;
      // Centre the block, then snap its left edge to a device pixel so every
      // glyph edge lands on the pixel grid.
      final spare = physicalWidth - fitColumns * scale * cellWidth;
      final physicalLeft = (leftInset * dpr + spare / 2 + _epsilon)
          .floorToDouble();
      return ReaderLayout(
        availableWidth: available,
        fontSize: fontSize,
        glyphAdvance: glyphAdvance,
        lineHeight: _snapToPhysical(fontSize * font.lineHeightRatio, dpr),
        textLeft: physicalLeft / dpr,
        contentColumns: contentColumns,
        devicePixelRatio: dpr,
        integerScale: scale,
      );
    }
  }

  final fitFontSize = available / (fitColumns * font.advanceRatio);
  return ReaderLayout(
    availableWidth: available,
    fontSize: fitFontSize,
    glyphAdvance: fitFontSize * font.advanceRatio,
    lineHeight: _snapToPhysical(fitFontSize * font.lineHeightRatio, dpr),
    textLeft: leftInset,
    contentColumns: contentColumns,
    devicePixelRatio: dpr,
    usedFallback: font.integerScale,
  );
}

// Whole physical pixels keep fixed-extent rows from drifting off the pixel
// grid as the line index grows.
double _snapToPhysical(double logical, double dpr) =>
    math.max(1, (logical * dpr).round()) / dpr;
