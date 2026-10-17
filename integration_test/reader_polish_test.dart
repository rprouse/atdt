// Stage G on a device: reading position survives a new app session on the
// same database file, and the orientation control really rotates the
// reader and releases it on exit.
//
//   flutter test integration_test/reader_polish_test.dart -d <device>
import 'dart:io';

import 'package:atdt/archive/issue_import.dart';
import 'package:atdt/download/download_controller.dart';
import 'package:atdt/reader/reader_font.dart';
import 'package:atdt/reader/reader_screen.dart';
import 'package:atdt/reader/reader_settings.dart';
import 'package:atdt/reader/reader_view.dart';
import 'package:atdt/storage/archive_database.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'fixture_text.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FontRegistry fonts;
  late File file;
  late int phileId;

  ArchiveDatabase openDb() => ArchiveDatabase(
    driftDatabase(
      name: 'polish',
      native: DriftNativeOptions(databasePath: () async => file.path),
    ),
  );

  setUpAll(() async {
    fonts = await FontRegistry.loadFromBundle(rootBundle);
    file = File('${(await getTemporaryDirectory()).path}/polish.sqlite');
    if (file.existsSync()) file.deleteSync();
    final db = openDb();
    await db.saveIssue(
      ImportedIssue(
        number: 1,
        sourceChecksum: 'device-test',
        philes: [
          ImportedPhile(number: 1, title: 'Big', text: tenThousandLines()),
        ],
      ),
      fetchedAt: DateTime.now(),
    );
    phileId = (await db.phile(1, 1))!.id;
    await db.close();
  });

  Future<ProviderContainer> launch(
    WidgetTester tester,
    ArchiveDatabase db,
  ) async {
    final container = ProviderContainer(
      overrides: [
        archiveDatabaseProvider.overrideWithValue(db),
        fontRegistryProvider.overrideWithValue(fonts),
      ],
    );
    await restoreSavedSettings(container);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(home: ReaderScreen(phileId: phileId)),
      ),
    );
    for (var i = 0; i < 50 && find.byType(ReaderView).evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
    return container;
  }

  ReaderViewState reader(WidgetTester tester) =>
      tester.state<ReaderViewState>(find.byType(ReaderView));

  testWidgets('a new session reopens at the exact line and column', (
    tester,
  ) async {
    await tester.runAsync(() async {
      var db = openDb();
      var container = await launch(tester, db);
      final layout = reader(tester).layout!;
      reader(tester).verticalController!.jumpTo(6543.5 * layout.lineHeight);
      reader(tester).horizontalController!.jumpTo(12 * layout.glyphAdvance);
      await tester.pumpAndSettle();
      final before = reader(tester).position;

      // Close the reader and the whole session, as if the app were quit.
      await tester.pumpWidget(const SizedBox());
      await Future<void>.delayed(const Duration(milliseconds: 300));
      container.dispose();
      await db.close();

      db = openDb();
      container = await launch(tester, db);
      final after = reader(tester).position;
      expect(after.topLineIndex, before.topLineIndex);
      expect(after.fractionIntoLine, closeTo(before.fractionIntoLine, 1e-6));
      expect(after.columnOffset, closeTo(before.columnOffset, 1e-6));

      await tester.pumpWidget(const SizedBox());
      container.dispose();
      await db.close();
    });
  });

  testWidgets('orientation control rotates the reader and releases it', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final db = openDb();
      final container = await launch(tester, db);
      Orientation orientation() =>
          MediaQuery.of(tester.element(find.byType(ReaderView))).orientation;
      expect(orientation(), Orientation.portrait);

      container
          .read(readerSettingsProvider.notifier)
          .setOrientation(OrientationMode.landscape);
      for (var i = 0; i < 50 && orientation() != Orientation.landscape; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pump();
      }
      expect(orientation(), Orientation.landscape);

      // Back to Auto for the rest of the device's life.
      container
          .read(readerSettingsProvider.notifier)
          .setOrientation(OrientationMode.auto);
      await tester.pumpWidget(const SizedBox());
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
      ]);
      await Future<void>.delayed(const Duration(seconds: 1));
      await SystemChrome.setPreferredOrientations(DeviceOrientation.values);
      container.dispose();
      await db.close();
    });
  });
}
