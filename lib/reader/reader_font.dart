import 'package:flutter/painting.dart';

import '../layout/layout_calculator.dart';

/// Ligatures and contextual alternates would merge columns; every font has
/// both disabled (AGENTS.md hard rule 6). JetBrains Mono ships its
/// ligatures in `calt`, so that is the one doing the work there.
const List<FontFeature> readerFontFeatures = [
  FontFeature.disable('liga'),
  FontFeature.disable('calt'),
];

/// A bundled reader font. Stage E replaces this list with a manifest.
class ReaderFont {
  const ReaderFont({
    required this.id,
    required this.displayName,
    required this.family,
    required this.lineHeightRatio,
    this.integerScale = false,
    this.cellWidthPx,
    this.nativeSizePx,
  });

  final String id;
  final String displayName;
  final String family;
  final double lineHeightRatio;
  final bool integerScale;
  final int? cellWidthPx;
  final int? nativeSizePx;

  MonoFontMetrics metrics(double advanceRatio) => MonoFontMetrics(
    advanceRatio: advanceRatio,
    lineHeightRatio: lineHeightRatio,
    integerScale: integerScale,
    cellWidthPx: cellWidthPx,
    nativeSizePx: nativeSizePx,
  );
}

const readerFonts = [
  // 1.32 is the font's own ascent + descent, so box-drawing verticals join.
  ReaderFont(
    id: 'jetbrains_mono',
    displayName: 'JetBrains Mono',
    family: 'JetBrainsMono',
    lineHeightRatio: 1.32,
  ),
  ReaderFont(
    id: 'pxplus_ibm_vga_8x16',
    displayName: 'IBM VGA 8x16',
    family: 'PxPlusIbmVga8x16',
    lineHeightRatio: 1,
    integerScale: true,
    cellWidthPx: 8,
    nativeSizePx: 16,
  ),
];

ReaderFont readerFontById(String id) =>
    readerFonts.firstWhere((f) => f.id == id, orElse: () => readerFonts.first);

const double _referenceSize = 100;
final Map<String, double> _advanceRatioCache = {};

/// Glyph advance divided by font size, measured rather than assumed.
///
/// Lays out 80 identical glyphs at a reference size, as the spec asks, so
/// per-glyph rounding averages out.
double measureAdvanceRatio(ReaderFont font) =>
    _advanceRatioCache.putIfAbsent(font.family, () {
      final painter = TextPainter(
        text: TextSpan(
          text: 'M' * fitColumns,
          style: TextStyle(
            fontFamily: font.family,
            fontSize: _referenceSize,
            fontFeatures: readerFontFeatures,
          ),
        ),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
        maxLines: 1,
      )..layout();
      final ratio = painter.width / (fitColumns * _referenceSize);
      painter.dispose();
      return ratio;
    });

/// Clears measured ratios; tests call this after loading real fonts.
void resetAdvanceRatioCache() => _advanceRatioCache.clear();
