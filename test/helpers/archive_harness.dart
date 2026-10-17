import 'dart:io';
import 'dart:typed_data';

import 'package:atdt/archive/archive_source.dart';
import 'package:atdt/archive/issue_import.dart';
import 'package:atdt/download/download_controller.dart';
import 'package:atdt/storage/archive_database.dart';
import 'package:drift/drift.dart' show DatabaseConnection;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

final Uint8List fixtureTarball = File('test/archive/fixtures/phrack99.tar.gz')
    .readAsBytesSync();

ArchiveDatabase memoryArchiveDatabase() => ArchiveDatabase(
  DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true),
);

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
