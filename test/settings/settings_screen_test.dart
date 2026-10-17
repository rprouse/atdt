import 'package:atdt/reader/about.dart';
import 'package:atdt/reader/reader_font.dart';
import 'package:atdt/reader/reader_settings.dart';
import 'package:atdt/settings/settings_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ProviderContainer> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 4000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final container = ProviderContainer();
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SettingsScreen()),
    ),
  );
  return container;
}

void main() {
  testWidgets('choosing a font, theme and orientation updates settings', (
    tester,
  ) async {
    final orientations = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'SystemChrome.setPreferredOrientations') {
          orientations.add(call.arguments);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final container = await _pump(tester);

    await tester.tap(find.byKey(const ValueKey('font-c64_pro_mono')));
    await tester.tap(find.byKey(const ValueKey('theme-paper')));
    await tester.tap(find.byKey(const ValueKey('orientation-landscape')));
    await tester.pumpAndSettle();

    final settings = container.read(readerSettingsProvider);
    expect(settings.fontId, 'c64_pro_mono');
    expect(settings.themeId, 'paper');
    expect(settings.orientation, OrientationMode.landscape);
    expect(orientations.single, [
      'DeviceOrientation.landscapeLeft',
      'DeviceOrientation.landscapeRight',
    ]);
  });

  testWidgets('every bundled font is offered', (tester) async {
    await _pump(tester);
    for (final font in readerFonts) {
      expect(find.byKey(ValueKey('font-${font.id}')), findsOneWidget);
    }
  });

  testWidgets('About lists a credit for every font', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('About ATDT'));
    await tester.pumpAndSettle();

    for (final font in readerFonts) {
      expect(find.byKey(ValueKey('credit-${font.id}')), findsOneWidget);
    }
    expect(find.textContaining('not affiliated with Phrack'), findsOneWidget);
  });

  testWidgets('font licences are registered with their shipped text', (
    tester,
  ) async {
    LicenseRegistry.reset();
    addTearDown(LicenseRegistry.reset);
    registerFontLicences();

    final entries = await tester.runAsync(
      () => LicenseRegistry.licenses.toList(),
    );
    final byPackage = {
      for (final e in entries!)
        e.packages.single: e.paragraphs.map((p) => p.text).join(' '),
    };

    expect(byPackage['JetBrains Mono (font)'], contains('SIL Open Font'));
    expect(
      byPackage['BigBlue Terminal (font)'],
      contains('Attribution-ShareAlike 4.0'),
    );
    expect(
      byPackage['C64 Pro Mono (font)'],
      contains('freely provided to end users'),
    );
  });
}
