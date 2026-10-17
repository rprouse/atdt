import 'package:atdt/app.dart';
import 'package:atdt/reader/reader_settings.dart';
import 'package:atdt/reader/reader_theme.dart';
import 'package:atdt/settings/settings_screen.dart';
import 'package:atdt/storage/archive_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/archive_harness.dart';
import '../helpers/reader_harness.dart';

Future<ProviderContainer> _openSettings(
  WidgetTester tester,
  ArchiveDatabase db,
) async {
  tester.view
    ..physicalSize = const Size(1170, 7000)
    ..devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final container = ProviderContainer(
    overrides: archiveOverrides(database: db),
  );
  addTearDown(container.dispose);
  await restoreSavedSettings(container);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SettingsScreen()),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Color _previewBackground(WidgetTester tester) =>
    (tester
                .widget<Container>(find.byKey(const ValueKey('theme-preview')))
                .decoration!
            as BoxDecoration)
        .color!;

void main() {
  setUpAll(loadReaderFonts);

  late ArchiveDatabase db;
  setUp(() => db = memoryArchiveDatabase());
  tearDown(() => db.close());

  testWidgets('create a theme with the picker; the preview updates live', (
    tester,
  ) async {
    final container = await _openSettings(tester, db);
    await tester.tap(find.byKey(const ValueKey('new-theme')));
    await tester.pumpAndSettle();

    // New themes start from the current one.
    expect(_previewBackground(tester), builtInThemes.first.background);

    await tester.enterText(find.byKey(const ValueKey('theme-name')), 'Dusk');
    await tester.enterText(find.byKey(const ValueKey('hex-field')), '#203040');
    await tester.pump();
    expect(_previewBackground(tester), const Color(0xFF203040));

    await tester.tap(find.byKey(const ValueKey('role-foreground')));
    await tester.pump();
    await tester.enterText(find.byKey(const ValueKey('hex-field')), '#FFEEDD');
    await tester.pump();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final custom = container.read(customThemesProvider).single;
    expect(custom.displayName, 'Dusk');
    expect(custom.background, const Color(0xFF203040));
    expect(custom.foreground, const Color(0xFFFFEEDD));
    expect(custom.builtIn, isFalse);
    // Saving selects it, and it is listed with the built-ins.
    expect(container.read(currentThemeProvider), custom);
    expect(find.text('Dusk'), findsOneWidget);
  });

  testWidgets('custom themes and the choice survive a restart', (tester) async {
    final first = await _openSettings(tester, db);
    first
        .read(customThemesProvider.notifier)
        .save(
          builtInThemes.first.copyWith(id: 'custom-a', displayName: 'Saved'),
        );
    first.read(readerSettingsProvider.notifier).setTheme('custom-a');
    await tester.pumpAndSettle();

    await tester.pumpWidget(const SizedBox());
    final relaunched = await _openSettings(tester, db);
    expect(relaunched.read(customThemesProvider).single.displayName, 'Saved');
    expect(relaunched.read(currentThemeProvider).id, 'custom-a');
  });

  testWidgets('edit, then delete, the theme in use', (tester) async {
    final container = await _openSettings(tester, db);
    container
        .read(customThemesProvider.notifier)
        .save(builtInThemes[2].copyWith(id: 'custom-b', displayName: 'Before'));
    container.read(readerSettingsProvider.notifier).setTheme('custom-b');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('edit-custom-b')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('theme-name')), 'After');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(container.read(customThemesProvider).single.displayName, 'After');
    expect(
      container.read(customThemesProvider).single.id,
      'custom-b',
      reason: 'editing keeps the id',
    );

    await tester.tap(find.byKey(const ValueKey('edit-custom-b')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete theme'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(container.read(customThemesProvider), isEmpty);
    // The deleted theme was in use: the default takes over.
    expect(container.read(currentThemeProvider), builtInThemes.first);
    expect(await db.setting(customThemesSettingKey), '[]');
  });

  testWidgets('built-in themes cannot be edited', (tester) async {
    await _openSettings(tester, db);
    for (final t in builtInThemes) {
      expect(find.byKey(ValueKey('edit-${t.id}')), findsNothing);
    }
  });

  testWidgets('the theme applies to the whole app, not just the reader', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: archiveOverrides(database: db),
    );
    addTearDown(container.dispose);
    container.read(readerSettingsProvider.notifier).setTheme('amber_phosphor');
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const AtdtApp()),
    );
    await tester.pumpAndSettle();

    final amber = builtInThemes.firstWhere((t) => t.id == 'amber_phosphor');
    // The app bar's own surface is the first Material inside it.
    final appBar = tester.widget<Material>(
      find
          .descendant(of: find.byType(AppBar), matching: find.byType(Material))
          .first,
    );
    expect(appBar.color, amber.background);
    final title = tester.widget<Text>(find.text('Phrack'));
    expect(
      DefaultTextStyle.of(tester.element(find.text('Phrack'))).style.color ??
          title.style?.color,
      amber.accent,
    );
  });
}
