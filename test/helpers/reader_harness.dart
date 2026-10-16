import 'dart:io';
import 'dart:math' as math;

import 'package:atdt/ingest/phile_text.dart';
import 'package:atdt/reader/reader_font.dart';
import 'package:atdt/reader/reader_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// Strict lookups: readerFontById falls back silently, which would hide a
// renamed font in tests.
ReaderFont _font(String id) => readerFonts.singleWhere((f) => f.id == id);
final jetBrainsMono = _font('jetbrains_mono');
final bigBlueTerminal = _font('bigblue_terminal_plus');
final c64ProMono = _font('c64_pro_mono');

/// Goldens are rendered and compared on Linux only (CI, or the Docker
/// script in tool/goldens/), because text rasterisation differs by OS.
final bool goldensSupported = Platform.isLinux;
const goldenSkipReason = 'Goldens run on Linux only: see tool/goldens/';

/// flutter_test renders with a placeholder font unless real ones are loaded.
Future<void> loadReaderFonts() async {
  const files = {
    'JetBrainsMono': 'assets/fonts/jetbrains_mono/JetBrainsMono-Regular.ttf',
    'BigBlueTerminalPlus':
        'assets/fonts/bigblue_terminal/BigBlue_TerminalPlus.TTF',
    'C64ProMono': 'assets/fonts/c64_pro_mono/C64_Pro_Mono-STYLE.ttf',
  };
  for (final MapEntry(key: family, value: path) in files.entries) {
    final bytes = File(path).readAsBytesSync();
    await (FontLoader(
      family,
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  }
  resetAdvanceRatioCache();
}

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
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  home: ColoredBox(
    color: background,
    child: ReaderView(key: key, text: text, font: font, foreground: foreground),
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
