import 'dart:io';
import 'dart:typed_data';

import 'package:atdt/archive/archive_source.dart';
import 'package:atdt/archive/issue_import.dart';
import 'package:atdt/download/download_controller.dart';
import 'package:atdt/ingest/phile_text.dart';
import 'package:atdt/storage/archive_database.dart';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

final Uint8List fixtureTarball = File('test/archive/fixtures/phrack99.tar.gz')
    .readAsBytesSync();

/// An in-memory database for widget tests. Decoding stays on the test
/// isolate: real isolates never complete under the widget tester's fake
/// clock. (Storage unit tests cover the isolate path in real time.)
ArchiveDatabase memoryArchiveDatabase() => ArchiveDatabase(
  DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
  decodeOnIsolateAbove: 1 << 30,
);

ImportedPhile phileFromFixture(
  int number,
  String fixture, {
  String? title,
  String? author,
}) => ImportedPhile(
  number: number,
  title: title ?? fixture,
  author: author,
  text: PhileText.fromBytes(File('test/fixtures/$fixture').readAsBytesSync()),
);

/// Stores one fixture as the only phile of [issue]; returns its id.
Future<int> seedPhile(
  ArchiveDatabase db,
  String fixture, {
  int issue = 1,
  String? title,
}) async {
  await db.saveIssue(
    ImportedIssue(
      number: issue,
      sourceChecksum: 'seed',
      philes: [phileFromFixture(1, fixture, title: title)],
    ),
    fetchedAt: DateTime.utc(2026),
  );
  return (await db.phile(issue, 1))!.id;
}

/// A small library: issues 96-100 in the catalog; 99 is the synthetic
/// tarball (3 philes); 98 has 40 short philes, enough to scroll.
Future<void> seedLibrary(ArchiveDatabase db) async {
  await db.saveCatalog({
    for (var n = 96; n <= 100; n++) n: DateTime.utc(1900 + n, 3, n - 90),
  });
  await db.saveIssue(
    importIssueArchive(99, fixtureTarball),
    fetchedAt: DateTime.utc(2026),
  );
  await db.saveIssue(
    ImportedIssue(
      number: 98,
      sourceChecksum: 'seed',
      philes: [
        for (var i = 1; i <= 40; i++)
          ImportedPhile(
            number: i,
            title: 'Phile title $i',
            author: 'Author $i',
            text: PhileText.fromBytes('phile $i\nsecond line\n'.codeUnits),
          ),
      ],
    ),
    fetchedAt: DateTime.utc(2026),
  );
}

/// Serves the fixture tarball for every listed issue.
class FakeArchiveSource implements ArchiveSource {
  FakeArchiveSource(this.issues);

  List<int> issues;
  bool offline = false;
  final fetched = <int>[];

  @override
  Future<List<int>> availableIssues({CancelToken? cancel}) async {
    if (offline) {
      throw const ArchiveNetworkException(
        "Can't reach the Phrack archive. Check your connection and try again.",
      );
    }
    return issues;
  }

  @override
  Future<Map<int, DateTime>> releaseDates({CancelToken? cancel}) async =>
      const {};

  @override
  Future<Uint8List> fetchIssue(
    int issue, {
    ProgressCallback? onProgress,
    CancelToken? cancel,
  }) async {
    fetched.add(issue);
    onProgress?.call(fixtureTarball.length, fixtureTarball.length);
    return fixtureTarball;
  }
}

/// Storage and network overrides for app-level widget tests: an in-memory
/// database, a fake archive, inline imports and no polite delay.
///
/// A [database] passed in belongs to the caller, so it outlives the
/// ProviderScope (e.g. across a simulated relaunch); close it in a tearDown.
List<Override> archiveOverrides({
  ArchiveDatabase? database,
  ArchiveSource? source,
}) => [
  archiveDatabaseProvider.overrideWith((ref) {
    if (database != null) return database;
    final db = memoryArchiveDatabase();
    ref.onDispose(db.close);
    return db;
  }),
  archiveSourceProvider.overrideWithValue(source ?? FakeArchiveSource([])),
  issueImporterProvider.overrideWithValue(
    (n, b) async => importIssueArchive(n, b),
  ),
  politeDelayProvider.overrideWithValue(Duration.zero),
];
