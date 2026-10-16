// Rotation and font changes on a real device, with real engine fonts.
//
//   flutter test integration_test/reader_rotation_test.dart -d <device>
import 'package:atdt/ingest/spike_text.dart';
import 'package:atdt/reader/reader_font.dart';
import 'package:atdt/reader/reader_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

const _portrait = Size(390, 844);
const _landscape = Size(844, 390);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late PhileText text;
  setUpAll(() async {
    final data = await rootBundle.load('test/fixtures/ten_thousand_lines.txt');
    text = PhileText.fromBytes(data.buffer.asUint8List());
  });

  Future<GlobalKey<ReaderViewState>> open(
    WidgetTester tester,
    ReaderFont font,
  ) async {
    final key = GlobalKey<ReaderViewState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderView(
            key: key,
            text: text,
            font: font,
            foreground: Colors.green,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return key;
  }

  void resize(WidgetTester tester, Size logical) {
    final dpr = tester.view.devicePixelRatio;
    tester.view.physicalSize = logical * dpr;
  }

  for (final font in readerFonts) {
    testWidgets('rotation holds line and column (${font.id})', (tester) async {
      addTearDown(tester.view.reset);
      resize(tester, _portrait);
      final key = await open(tester, font);

      final layout = key.currentState!.layout!;
      key.currentState!.verticalController!.jumpTo(6789.3 * layout.lineHeight);
      key.currentState!.horizontalController!.jumpTo(20 * layout.glyphAdvance);
      await tester.pumpAndSettle();
      final before = key.currentState!.position;

      for (var i = 0; i < 6; i++) {
        resize(tester, i.isEven ? _landscape : _portrait);
        await tester.pumpAndSettle();
        final after = key.currentState!.position;
        expect(
          (after.topLineIndex - before.topLineIndex).abs(),
          lessThanOrEqualTo(1),
        );
        expect(after.columnOffset, closeTo(before.columnOffset, 1e-6));
      }
    });
  }

  testWidgets('switching fonts mid-file keeps the top line', (tester) async {
    addTearDown(tester.view.reset);
    resize(tester, _portrait);
    final key = await open(tester, readerFonts.first);
    final layout = key.currentState!.layout!;
    key.currentState!.verticalController!.jumpTo(5000 * layout.lineHeight);
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderView(
            key: key,
            text: text,
            font: readerFonts.last,
            foreground: Colors.green,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(key.currentState!.position.topLineIndex, 5000);
  });
}
