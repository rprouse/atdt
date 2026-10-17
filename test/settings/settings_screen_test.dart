import 'package:atdt/reader/about.dart';
import 'package:atdt/reader/reader_settings.dart';
import 'package:atdt/settings/credits_screen.dart';
import 'package:atdt/settings/settings_screen.dart';
import 'package:atdt/storage/archive_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/archive_harness.dart';
import '../helpers/reader_harness.dart';

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  Widget home = const SettingsScreen(),
  ArchiveDatabase? db,
}) async {
  tester.view.physicalSize = const Size(1170, 5000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final database = db ?? memoryArchiveDatabase();
  if (db == null) addTearDown(database.close);
  final container = ProviderContainer(
    overrides: archiveOverrides(database: database),
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: home),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  setUpAll(loadReaderFonts);

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
    expect(container.read(currentFontProvider).id, 'c64_pro_mono');
    expect(container.read(currentThemeProvider).id, 'paper');
    expect(settings.orientation, OrientationMode.landscape);
    expect(orientations.single, [
      'DeviceOrientation.landscapeLeft',
      'DeviceOrientation.landscapeRight',
    ]);
  });

  testWidgets('every manifest font is offered, defaulting to the first', (
    tester,
  ) async {
    final container = await _pump(tester);
    for (final font in testFonts.fonts) {
      expect(find.byKey(ValueKey('font-${font.id}')), findsOneWidget);
    }
    expect(container.read(currentFontProvider), testFonts.defaultFont);
  });

  testWidgets('the font choice survives a restart', (tester) async {
    final db = memoryArchiveDatabase();
    addTearDown(db.close);
    await _pump(tester, db: db);
    await tester.tap(find.byKey(const ValueKey('font-terminus')));
    await tester.pumpAndSettle();
    expect(await db.setting(fontSettingKey), 'terminus');

    // A new app session on the same database.
    await tester.pumpWidget(const SizedBox());
    final relaunched = await _pump(tester, db: db);
    expect(relaunched.read(currentFontProvider).id, 'terminus');
  });

  testWidgets('a stored font that is no longer bundled falls back', (
    tester,
  ) async {
    final db = memoryArchiveDatabase();
    addTearDown(db.close);
    await db.setSetting(fontSettingKey, 'removed_font');
    final container = await _pump(tester, db: db);
    expect(container.read(currentFontProvider), testFonts.defaultFont);
  });

  testWidgets('Credits lists every font with its licence text', (tester) async {
    await _pump(tester, home: const CreditsScreen());
    for (final font in testFonts.fonts) {
      expect(find.byKey(ValueKey('font-credit-${font.id}')), findsOneWidget);
    }
    expect(find.textContaining('not affiliated with Phrack'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('font-credit-c64_pro_mono')));
    await tester.pumpAndSettle();
    expect(find.textContaining('freely provided to end users'), findsOneWidget);
  });

  testWidgets('About lists a credit for every font', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('About ATDT'));
    await tester.pumpAndSettle();

    for (final font in testFonts.fonts) {
      expect(find.byKey(ValueKey('credit-${font.id}')), findsOneWidget);
    }
  });

  testWidgets('font licences are registered from the manifest', (tester) async {
    LicenseRegistry.reset();
    addTearDown(LicenseRegistry.reset);
    // rootBundle caches load futures. One cached by an earlier test belongs
    // to that test's fake-async zone and never completes under runAsync.
    rootBundle.clear();
    registerFontLicences(testFonts, rootBundle);

    final entries = await tester.runAsync(
      () => LicenseRegistry.licenses.toList(),
    );
    final byPackage = {
      for (final e in entries!)
        e.packages.single: e.paragraphs.map((p) => p.text).join(' '),
    };

    expect(byPackage, hasLength(testFonts.fonts.length));
    expect(byPackage['JetBrains Mono (font)'], contains('SIL Open Font'));
    expect(byPackage['Terminus (font)'], contains('Terminus Font'));
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
