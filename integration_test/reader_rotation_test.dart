// Rotation and font changes on a real device, with real engine fonts.
//
//   flutter test integration_test/reader_rotation_test.dart -d <device>
import 'package:atdt/reader/reader_font.dart';
import 'package:atdt/reader/reader_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'fixture_text.dart';

const _portrait = Size(390, 844);
const _landscape = Size(844, 390);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FontRegistry fonts;
  setUpAll(() async => fonts = await FontRegistry.loadFromBundle(rootBundle));

  final text = tenThousandLines();

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

  testWidgets('rotation holds line and column, for every font', (tester) async {
    for (final font in fonts.fonts) {
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
          reason: font.id,
        );
        expect(
          after.columnOffset,
          closeTo(before.columnOffset, 1e-6),
          reason: font.id,
        );
      }
    }
  });

  testWidgets('switching fonts mid-file keeps the top line', (tester) async {
    addTearDown(tester.view.reset);
    resize(tester, _portrait);
    final key = await open(tester, fonts.defaultFont);
    final layout = key.currentState!.layout!;
    key.currentState!.verticalController!.jumpTo(5000 * layout.lineHeight);
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ReaderView(
            key: key,
            text: text,
            font: fonts.fonts.last,
            foreground: Colors.green,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(key.currentState!.position.topLineIndex, 5000);
  });
}
