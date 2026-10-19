// The walk integration_test/app_test.dart makes on a device with an
// archive stored, on the whole app: library -> issue -> phile -> reader ->
// back, with the search indexer running as it does after a download.
import 'package:atdt/app.dart';
import 'package:atdt/library/issues_screen.dart';
import 'package:atdt/library/search_providers.dart';
import 'package:atdt/reader/reader_settings.dart';
import 'package:atdt/reader/reader_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/archive_harness.dart';
import 'helpers/reader_harness.dart';

void main() {
  setUpAll(loadReaderFonts);

  testWidgets('library -> issue -> phile -> reader -> back', (tester) async {
    setSurface(tester, const Size(390, 844));
    addTearDown(tester.view.reset);
    final db = memoryArchiveDatabase();
    addTearDown(db.close);
    await seedLibrary(db);
    final container = ProviderContainer(
      overrides: archiveOverrides(database: db),
    );
    addTearDown(container.dispose);
    await restoreSavedSettings(container);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const AtdtApp()),
    );
    await tester.pumpAndSettle();
    expect(find.byType(IssuesScreen), findsOneWidget);
    expect(container.read(searchIndexerProvider)?.complete, isTrue);

    // As app_test finds them.
    final issue = find.textContaining(RegExp(r'· \d+ philes$'));
    expect(issue, findsWidgets);
    await tester.tap(issue.first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(ListTile).first);
    await tester.pumpAndSettle();
    expect(find.byType(ReaderView), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(ReaderView), findsNothing);
  });
}
