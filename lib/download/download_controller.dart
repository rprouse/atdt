import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../archive/archive_downloader.dart';
import '../archive/archive_source.dart';
import '../storage/archive_database.dart';
import '../storage/database_file.dart';

final archiveDatabaseProvider = Provider<ArchiveDatabase>((ref) {
  final db = openArchiveDatabase();
  ref.onDispose(db.close);
  return db;
});

final archiveSourceProvider = Provider<ArchiveSource>((ref) {
  final source = HttpArchiveSource();
  ref.onDispose(source.close);
  return source;
});

/// Overridable so widget tests can import inline instead of on an isolate.
final issueImporterProvider = Provider<IssueImporter>((_) => importOnIsolate);

final politeDelayProvider = Provider<Duration>(
  (_) => const Duration(seconds: 1),
);

final archiveCountsProvider = FutureProvider<ArchiveCounts>(
  (ref) => ref.watch(archiveDatabaseProvider).counts(),
);

/// Persisted so a download killed with the app resumes on the next launch.
const downloadStateKey = 'archive.download';
const _requested = 'requested';
const _settled = 'settled';

/// Approximate size of the whole archive (72 issues), measured 2026-10-16.
const archiveDownloadMegabytes = 31;

/// The running or last download; null before the first one this session.
class DownloadController extends Notifier<DownloadProgress?> {
  CancelToken? _cancel;
  StreamSubscription<DownloadProgress>? _subscription;

  @override
  DownloadProgress? build() {
    ref.onDispose(() {
      _cancel?.cancel();
      unawaited(_subscription?.cancel());
    });
    return null;
  }

  bool get isRunning => state != null && !state!.isFinished;

  /// Downloads every issue not yet stored. Also "check for new issues".
  Future<void> start() async {
    if (isRunning) return;
    final db = ref.read(archiveDatabaseProvider);
    await db.setSetting(downloadStateKey, _requested);
    final cancel = _cancel = CancelToken();
    final downloader = ArchiveDownloader(
      source: ref.read(archiveSourceProvider),
      store: db,
      importer: ref.read(issueImporterProvider),
      politeDelay: ref.read(politeDelayProvider),
    );
    state = const DownloadProgress(phase: DownloadPhase.checking);
    // The previous run has finished (start returns early while one is
    // running), so there is nothing to wait for.
    unawaited(_subscription?.cancel());
    _subscription = downloader.run(cancel: cancel).listen((progress) {
      state = progress;
      if (progress.phase == DownloadPhase.importing || progress.isFinished) {
        ref.invalidate(archiveCountsProvider);
      }
      // A network failure leaves the request pending, so it resumes later.
      if (progress.phase == DownloadPhase.done ||
          progress.phase == DownloadPhase.cancelled) {
        unawaited(db.setSetting(downloadStateKey, _settled));
      }
    });
  }

  void cancel() => _cancel?.cancel();

  /// Called at launch: picks up a download the app was killed during.
  Future<void> resumeIfInterrupted() async {
    final db = ref.read(archiveDatabaseProvider);
    if (await db.setting(downloadStateKey) == _requested) await start();
  }
}

final downloadControllerProvider =
    NotifierProvider<DownloadController, DownloadProgress?>(
      DownloadController.new,
    );
