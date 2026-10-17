import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../fonts/font_manifest.dart';
import '../fonts/glyph_coverage.dart';
import '../layout/layout_calculator.dart';

/// Ligatures and contextual alternates would merge columns; every font has
/// both disabled (AGENTS.md hard rule 6). JetBrains Mono ships its
/// ligatures in `calt`, so that is the one doing the work there.
const List<FontFeature> readerFontFeatures = [
  FontFeature.disable('liga'),
  FontFeature.disable('calt'),
];

/// A loaded reader font: its manifest entry plus the characters it can draw.
///
/// [integerScale] fonts render at whole multiples of their native cell
/// (see the layout calculator). No bundled font uses it at the moment: the
/// retro fonts are drawn as outlines at fit size so they fill the width in
/// portrait, where an 8-pixel cell only reaches 1x on phones.
class ReaderFont {
  const ReaderFont({required this.spec, required this.coverage});

  final FontSpec spec;
  final GlyphCoverage coverage;

  String get id => spec.id;
  String get displayName => spec.displayName;
  String get family => spec.family;
  double get lineHeightRatio => spec.lineHeightRatio;
  bool get integerScale => spec.integerScale;

  MonoFontMetrics metrics(double advanceRatio) => MonoFontMetrics(
    advanceRatio: advanceRatio,
    lineHeightRatio: spec.lineHeightRatio,
    integerScale: spec.integerScale,
    cellWidthPx: spec.cellWidthPx,
    nativeSizePx: spec.nativeSizePx,
  );
}

/// Every reader font from `assets/fonts/manifest.json`, registered with the
/// engine. Loaded once at startup.
class FontRegistry {
  FontRegistry(List<ReaderFont> fonts) : fonts = List.unmodifiable(fonts);

  static const manifestPath = 'assets/fonts/manifest.json';
  static const _root = 'assets/fonts/';

  /// Reads the manifest, registers each font family with the engine and
  /// reads its coverage from the same bytes.
  static Future<FontRegistry> load({
    required Future<String> Function(String path) loadString,
    required Future<ByteData> Function(String path) loadBytes,
  }) async {
    final manifest = FontManifest.parse(await loadString(manifestPath));
    final fonts = <ReaderFont>[];
    for (final spec in manifest.fonts) {
      final loader = FontLoader(spec.family);
      final codePoints = <int>{};
      for (final file in spec.files) {
        final data = await loadBytes('$_root$file');
        codePoints.addAll(
          GlyphCoverage.fromFontBytes(
            data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
          ).codePoints,
        );
        loader.addFont(Future.value(data));
      }
      await loader.load();
      fonts.add(ReaderFont(spec: spec, coverage: GlyphCoverage(codePoints)));
    }
    resetAdvanceRatioCache();
    return FontRegistry(fonts);
  }

  static Future<FontRegistry> loadFromBundle(AssetBundle bundle) =>
      load(loadString: bundle.loadString, loadBytes: bundle.load);

  /// In manifest order; the first is the default.
  final List<ReaderFont> fonts;

  ReaderFont get defaultFont => fonts.first;

  /// The font with [id], or the default if it is no longer bundled.
  ReaderFont byId(String id) =>
      fonts.firstWhere((f) => f.id == id, orElse: () => defaultFont);

  /// The first font (in manifest order) that can draw every character in
  /// [inventory], or null if none can.
  ReaderFont? firstCovering(Iterable<int> inventory) {
    for (final font in fonts) {
      if (font.coverage.coversAll(inventory)) return font;
    }
    return null;
  }

  /// Full path of a font's licence text in the asset bundle.
  static String licencePath(ReaderFont font) =>
      '$_root${font.spec.licenceFile}';
}

/// Overridden in `main` (and tests) with the loaded registry.
final fontRegistryProvider = Provider<FontRegistry>(
  (_) => throw StateError('fontRegistryProvider must be overridden'),
);

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
