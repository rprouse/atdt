import 'dart:io';
import 'dart:math' as math;

import 'package:atdt/fonts/font_manifest.dart';
import 'package:atdt/ingest/phile_text.dart';
import 'package:atdt/reader/reader_font.dart';
import 'package:atdt/reader/reader_view.dart';
import 'package:atdt/search/search_query.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

FontRegistry? _testFonts;

/// The real fonts from assets/fonts/manifest.json, registered with the test
/// engine (which otherwise draws every glyph with a placeholder font).
/// Call [loadReaderFonts] in `setUpAll` first.
FontRegistry get testFonts =>
    _testFonts ?? (throw StateError('call loadReaderFonts() in setUpAll'));

bool get testFontsLoaded => _testFonts != null;

Future<void> loadReaderFonts() async {
  _testFonts ??= await FontRegistry.load(
    loadString: (path) async => File(path).readAsStringSync(),
    loadBytes: (path) async =>
        ByteData.sublistView(File(path).readAsBytesSync()),
  );
  resetAdvanceRatioCache();
}

/// Font ids in manifest order, readable while tests are being declared
/// (before setUpAll has loaded the fonts).
final List<String> manifestFontIds = [
  for (final f in FontManifest.parse(
    File('assets/fonts/manifest.json').readAsStringSync(),
  ).fonts)
    f.id,
];

// Strict lookups: FontRegistry.byId falls back silently to the default,
// which would hide a renamed font in tests.
ReaderFont fontById(String id) =>
    testFonts.fonts.singleWhere((f) => f.id == id);
ReaderFont get jetBrainsMono => fontById('jetbrains_mono');
ReaderFont get bigBlueTerminal => fontById('bigblue_terminal_plus');
ReaderFont get c64ProMono => fontById('c64_pro_mono');
ReaderFont get terminus => fontById('terminus');

/// Goldens are rendered and compared on Linux only (CI, or the Docker
/// script in tool/goldens/), because text rasterisation differs by OS.
final bool goldensSupported = Platform.isLinux;
const goldenSkipReason = 'Goldens run on Linux only: see tool/goldens/';

PhileText fixture(String name) =>
    PhileText.fromBytes(File('test/fixtures/$name').readAsBytesSync());

/// Sets the test view to a phone-sized surface, in logical pixels.
void setSurface(WidgetTester tester, Size logical, {double dpr = 3}) {
  tester.view
    ..devicePixelRatio = dpr
    ..physicalSize = logical * dpr;
}

Widget readerApp({
  required PhileText text,
  required ReaderFont font,
  Color background = const Color(0xFF0A120A),
  Color foreground = const Color(0xFF41FF63),
  GlobalKey<ReaderViewState>? key,
  SearchQuery? highlight,
  Color? selection,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  home: ColoredBox(
    color: background,
    child: ReaderView(
      key: key,
      text: text,
      font: font,
      foreground: foreground,
      highlight: highlight,
      selectionColor: selection,
    ),
  ),
);

/// Global left and right edges of the shaped glyphs in the line [text].
({double left, double right}) glyphExtent(WidgetTester tester, String text) {
  final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
  final boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: text.length),
  );
  final left = boxes.map((b) => b.left).reduce(math.min);
  final right = boxes.map((b) => b.right).reduce(math.max);
  return (
    left: paragraph.localToGlobal(Offset(left, 0)).dx,
    right: paragraph.localToGlobal(Offset(right, 0)).dx,
  );
}
