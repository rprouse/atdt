// Stage J: the CRT effect's switches, its frame-budget guard and Settings.
// ImageFilter.shader needs Impeller, which `flutter test` does not use, so
// the drawn effect is checked on a device (docs/decisions.md).
import 'dart:ui' as ui;

import 'package:atdt/reader/crt_effect.dart';
import 'package:atdt/reader/reader_screen.dart';
import 'package:atdt/reader/reader_settings.dart';
import 'package:atdt/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/archive_harness.dart';
import '../helpers/reader_harness.dart';

const _budget = Duration(microseconds: 16667);
const _fast = Duration(milliseconds: 8);
const _slow = Duration(milliseconds: 24);

void main() {
  group('frame budget guard', () {
    bool run(FrameBudgetGuard guard, int slow, {int frames = 120}) {
      var failed = false;
      for (var i = 0; i < frames; i++) {
        failed |= guard.add(i < slow ? _slow : _fast);
      }
      return failed;
    }

    test('passes a device that keeps up', () {
      expect(run(FrameBudgetGuard(budget: _budget), 0, frames: 1200), isFalse);
    });

    test('fails when over a quarter of a window misses the budget', () {
      expect(run(FrameBudgetGuard(budget: _budget), 30), isFalse);
      expect(run(FrameBudgetGuard(budget: _budget), 31), isTrue);
    });

    test('judges each window afresh', () {
      final guard = FrameBudgetGuard(budget: _budget);
      expect(run(guard, 30), isFalse);
      expect(run(guard, 30), isFalse, reason: 'slow frames do not carry over');
    });

    test('says nothing until a window is complete', () {
      expect(run(FrameBudgetGuard(budget: _budget), 119, frames: 119), isFalse);
    });
  });

  group('when the effect is drawn', () {
    const on = ReaderSettings(crt: true);
    test('only when on, supported and not ruled out by accessibility', () {
      expect(
        crtBlock(settings: on, supported: true, accessibility: false),
        isNull,
      );
      expect(
        crtBlock(
          settings: const ReaderSettings(),
          supported: true,
          accessibility: false,
        ),
        CrtBlock.off,
      );
      expect(
        crtBlock(settings: on, supported: false, accessibility: false),
        CrtBlock.unsupported,
      );
      expect(
        crtBlock(settings: on, supported: true, accessibility: true),
        CrtBlock.accessibility,
      );
      expect(
        crtBlock(
          settings: const ReaderSettings(crtTooSlow: true),
          supported: true,
          accessibility: false,
        ),
        CrtBlock.tooSlow,
      );
    });
  });

  group('settings', () {
    setUpAll(loadReaderFonts);

    test('turning the effect on forgets a "too slow" verdict', () async {
      final db = memoryArchiveDatabase();
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: archiveOverrides(database: db),
      );
      addTearDown(container.dispose);
      final notifier = container.read(readerSettingsProvider.notifier);
      await notifier.restored;

      notifier
        ..setCrt(true)
        ..markCrtTooSlow();
      var s = container.read(readerSettingsProvider);
      expect((s.crt, s.crtTooSlow), (false, true));

      notifier.setCrt(true);
      s = container.read(readerSettingsProvider);
      expect((s.crt, s.crtTooSlow), (true, false));
    });

    testWidgets('choices persist', (tester) async {
      final db = memoryArchiveDatabase();
      addTearDown(db.close);
      Future<ProviderContainer> launch() async {
        final c = ProviderContainer(overrides: archiveOverrides(database: db));
        addTearDown(c.dispose);
        await c.read(readerSettingsProvider.notifier).restored;
        return c;
      }

      (await launch()).read(readerSettingsProvider.notifier)
        ..setCrt(true)
        ..setCrtIntensity(0.3);
      await tester.pump();
      final s = (await launch()).read(readerSettingsProvider);
      expect((s.crt, s.crtIntensity), (true, 0.3));
    });
  });

  group('Settings screen', () {
    setUpAll(loadReaderFonts);

    Future<ProviderContainer> pump(
      WidgetTester tester, {
      ui.FragmentProgram? program,
      bool disableAnimations = false,
    }) async {
      tester.view.physicalSize = const Size(1170, 9000);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      final db = memoryArchiveDatabase();
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [
          ...archiveOverrides(database: db),
          crtProgramProvider.overrideWith((ref) async => program),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MediaQuery(
            data: MediaQueryData(disableAnimations: disableAnimations),
            child: const MaterialApp(home: SettingsScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return container;
    }

    SwitchListTile crtSwitch(WidgetTester tester) =>
        tester.widget(find.byKey(const ValueKey('crt')));

    testWidgets('unavailable without shader filters', (tester) async {
      await pump(tester);
      expect(find.text('Not available on this device'), findsOneWidget);
      expect(crtSwitch(tester).onChanged, isNull);
    });

    group('with the shader', () {
      late ui.FragmentProgram program;
      setUpAll(() async {
        program = await ui.FragmentProgram.fromAsset('shaders/crt.frag');
      });

      testWidgets('off by default; the slider follows the switch', (
        tester,
      ) async {
        final container = await pump(tester, program: program);
        expect(crtSwitch(tester).value, isFalse);
        Slider slider() =>
            tester.widget(find.byKey(const ValueKey('crt-intensity')));
        expect(slider().onChanged, isNull);

        await tester.tap(find.byKey(const ValueKey('crt')));
        await tester.pumpAndSettle();
        expect(container.read(readerSettingsProvider).crt, isTrue);
        expect(slider().onChanged, isNotNull);
      });

      testWidgets('says when accessibility settings pause it', (tester) async {
        final container = await pump(
          tester,
          program: program,
          disableAnimations: true,
        );
        container.read(readerSettingsProvider.notifier).setCrt(true);
        await tester.pumpAndSettle();
        expect(find.textContaining('Paused while reduced motion'), findsOne);
      });

      testWidgets('says when the device was too slow', (tester) async {
        final container = await pump(tester, program: program);
        container.read(readerSettingsProvider.notifier).markCrtTooSlow();
        await tester.pumpAndSettle();
        expect(find.textContaining('could not keep up'), findsOneWidget);
      });
    });
  });

  testWidgets('without shader filters the reader shows plain text', (
    tester,
  ) async {
    setSurface(tester, const Size(390, 844));
    addTearDown(tester.view.reset);
    final db = memoryArchiveDatabase();
    addTearDown(db.close);
    final id = await seedPhile(db, 'tabs_code.txt');
    final container = ProviderContainer(
      overrides: archiveOverrides(database: db),
    );
    addTearDown(container.dispose);
    container.read(readerSettingsProvider.notifier).setCrt(true);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: ReaderScreen(phileId: id)),
      ),
    );
    await tester.pumpAndSettle();
    expect(ui.ImageFilter.isShaderFilterSupported, isFalse);
    expect(find.byKey(const ValueKey('crt')), findsNothing);
    expect(find.text('int main(int argc, char **argv)'), findsOneWidget);
  });
}
