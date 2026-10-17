import 'dart:io';
import 'dart:typed_data';

import 'package:atdt/archive/archive_downloader.dart';
import 'package:atdt/archive/archive_source.dart';
import 'package:atdt/archive/issue_import.dart';
import 'package:atdt/storage/archive_database.dart';
import 'package:flutter_test/flutter_test.dart';

final Uint8List _goodTarball = File('test/archive/fixtures/phrack99.tar.gz')
    .readAsBytesSync();

class _FakeSource implements ArchiveSource {
  _FakeSource(this.issues);

  final List<int> issues;
  final fetched = <int>[];
  final missing = <int>{};
  final corrupt = <int>{};
  int? offlineAt;
  bool datesFail = false;
  void Function(int issue)? onFetch;

  @override
  Future<List<int>> availableIssues({CancelToken? cancel}) async => issues;

  @override
  Future<Map<int, DateTime>> releaseDates({CancelToken? cancel}) async {
    if (datesFail) return const {};
    return {for (final n in issues) n: DateTime.utc(1985 + n, 1, 1)};
  }

  @override
  Future<Uint8List> fetchIssue(
    int issue, {
    ProgressCallback? onProgress,
    CancelToken? cancel,
  }) async {
    cancel?.throwIfCancelled();
    onFetch?.call(issue);
    if (issue == offlineAt) {
      throw const ArchiveNetworkException('offline');
    }
    if (missing.contains(issue)) {
      throw ArchiveHttpException(404, Uri.parse('x'));
    }
    fetched.add(issue);
    onProgress?.call(_goodTarball.length, _goodTarball.length);
    return corrupt.contains(issue)
        ? Uint8List.fromList([1, 2, 3])
        : _goodTarball;
  }
}

class _FakeStore implements ArchiveStore {
  final saved = <int, ImportedIssue>{};
  final dates = <int, DateTime?>{};

  @override
  Future<Set<int>> storedIssueNumbers() async => saved.keys.toSet();

  @override
  Future<void> saveIssue(
    ImportedIssue issue, {
    required DateTime fetchedAt,
    DateTime? releaseDate,
  }) async {
    saved[issue.number] = issue;
    dates[issue.number] = releaseDate;
  }

  @override
  Future<ArchiveCounts> counts() async => ArchiveCounts(
    issues: saved.length,
    philes: saved.values.fold(0, (n, i) => n + i.philes.length),
  );
}

// Imports inline (no isolate) so tests stay fast and deterministic.
Future<ImportedIssue> _inline(int n, Uint8List b) async =>
    importIssueArchive(n, b);

void main() {
  late _FakeSource source;
  late _FakeStore store;

  ArchiveDownloader downloader() => ArchiveDownloader(
    source: source,
    store: store,
    importer: _inline,
    politeDelay: Duration.zero,
  );

  setUp(() => store = _FakeStore());

  test('downloads every issue in order and reports counts', () async {
    source = _FakeSource([1, 2, 3]);
    final events = await downloader().run().toList();

    expect(source.fetched, [1, 2, 3]);
    expect(events.first.phase, DownloadPhase.checking);
    final last = events.last;
    expect(last.phase, DownloadPhase.done);
    expect((last.completed, last.total), (3, 3));
    expect((last.counts!.issues, last.counts!.philes), (3, 9));
    expect(store.dates[2], DateTime.utc(1987, 1, 1));
  });

  test('resumes: only issues not yet stored are fetched', () async {
    source = _FakeSource([1, 2, 3]);
    await downloader().run().toList();
    source = _FakeSource([1, 2, 3, 4]);

    final last = (await downloader().run().toList()).last;
    expect(source.fetched, [4]);
    expect((last.completed, last.total), (1, 1));
  });

  test('nothing to do is a quick done', () async {
    source = _FakeSource([1]);
    await downloader().run().toList();
    source = _FakeSource([1]);
    final events = await downloader().run().toList();
    expect(events.last.phase, DownloadPhase.done);
    expect(source.fetched, isEmpty);
  });

  test('going offline stops the run with a recoverable error', () async {
    source = _FakeSource([1, 2, 3])..offlineAt = 2;
    final last = (await downloader().run().toList()).last;

    expect(last.phase, DownloadPhase.failed);
    expect(last.error, 'offline');
    expect(store.saved.keys, [1]);

    // Back online: a retry picks up where it stopped.
    source = _FakeSource([1, 2, 3]);
    final retry = (await downloader().run().toList()).last;
    expect(retry.phase, DownloadPhase.done);
    expect(source.fetched, [2, 3]);
  });

  test('a missing or corrupt issue is skipped and reported', () async {
    source = _FakeSource([1, 2, 3])
      ..missing.add(2)
      ..corrupt.add(3);
    final last = (await downloader().run().toList()).last;

    expect(last.phase, DownloadPhase.done);
    expect(last.failedIssues, [2, 3]);
    expect(store.saved.keys, [1]);
  });

  test('cancelling stops between issues and keeps what is done', () async {
    final cancel = CancelToken();
    source = _FakeSource([1, 2, 3])
      ..onFetch = (n) {
        if (n == 2) cancel.cancel();
      };
    final last = (await downloader().run(cancel: cancel).toList()).last;

    expect(last.phase, DownloadPhase.cancelled);
    expect(store.saved.keys, [1]);
  });

  test('missing release dates do not stop the download', () async {
    source = _FakeSource([1])..datesFail = true;
    final last = (await downloader().run().toList()).last;
    expect(last.phase, DownloadPhase.done);
    expect(store.dates[1], isNull);
  });

  test('the default importer runs on an isolate', () async {
    final imported = await importOnIsolate(99, _goodTarball);
    expect(imported.philes, hasLength(3));
  });
}
