import 'package:flutter/painting.dart';

import '../layout/layout_calculator.dart';

/// Ligatures and contextual alternates would merge columns; every font has
/// both disabled (AGENTS.md hard rule 6). JetBrains Mono ships its
/// ligatures in `calt`, so that is the one doing the work there.
const List<FontFeature> readerFontFeatures = [
  FontFeature.disable('liga'),
  FontFeature.disable('calt'),
];

/// Licence and credit for a bundled font, shown in the About dialog.
class FontCredit {
  const FontCredit({
    required this.licenceName,
    required this.licenceAsset,
    required this.attribution,
  });

  final String licenceName;

  /// Asset path of the licence text shipped with the font.
  final String licenceAsset;
  final String attribution;
}

/// A bundled reader font. Stage E replaces this list with a manifest.
///
/// [integerScale] fonts render at whole multiples of their native cell
/// (see the layout calculator). No bundled font uses it at the moment: the
/// retro fonts are drawn as outlines at fit size so they fill the width in
/// portrait, where an 8-pixel cell only reaches 1x on phones.
class ReaderFont {
  const ReaderFont({
    required this.id,
    required this.displayName,
    required this.family,
    required this.lineHeightRatio,
    required this.credit,
    this.integerScale = false,
    this.cellWidthPx,
    this.nativeSizePx,
  });

  final String id;
  final String displayName;
  final String family;
  final double lineHeightRatio;
  final FontCredit credit;
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

// Line height ratios are each font's own ascent + descent, so box-drawing
// verticals join from one line to the next.
const readerFonts = [
  ReaderFont(
    id: 'jetbrains_mono',
    displayName: 'JetBrains Mono',
    family: 'JetBrainsMono',
    lineHeightRatio: 1.32,
    credit: FontCredit(
      licenceName: 'SIL Open Font License 1.1',
      licenceAsset: 'assets/fonts/jetbrains_mono/OFL.txt',
      attribution:
          'JetBrains Mono 2.304, copyright 2020 The JetBrains Mono Project '
          'Authors (github.com/JetBrains/JetBrainsMono).',
    ),
  ),
  ReaderFont(
    id: 'bigblue_terminal_plus',
    displayName: 'BigBlue Terminal',
    family: 'BigBlueTerminalPlus',
    lineHeightRatio: 1,
    credit: FontCredit(
      licenceName: 'CC BY-SA 4.0',
      licenceAsset: 'assets/fonts/bigblue_terminal/LICENSE.TXT',
      attribution:
          'BigBlue TerminalPlus 1.0 by VileR (int10h.org), based on the '
          'IBM 8x14 EGA/VGA charset.',
    ),
  ),
  ReaderFont(
    id: 'c64_pro_mono',
    displayName: 'C64 Pro Mono',
    family: 'C64ProMono',
    lineHeightRatio: 1,
    credit: FontCredit(
      licenceName: 'Style C64 TrueType licence',
      licenceAsset: 'assets/fonts/c64_pro_mono/license.txt',
      attribution:
          'C64 Pro Mono 1.2.1, (c) 2010-2019 Style '
          '(style64.org/c64-truetype).',
    ),
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
