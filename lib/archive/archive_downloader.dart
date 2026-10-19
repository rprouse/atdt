/// First-launch download and "check for new issues": fetch every issue not
/// yet stored, sequentially and politely, import each off the UI isolate,
/// and store it atomically. Pure Dart; no Flutter imports.
library;

import 'dart:async';
import 'dart:developer' as developer;
import 'dart:isolate';
import 'dart:typed_data';

import '../storage/archive_database.dart' show ArchiveCounts, ArchiveStore;
import 'archive_source.dart';
import 'issue_import.dart';
import 'tar_reader.dart';

enum DownloadPhase { checking, downloading, importing, done, cancelled, failed }

class DownloadProgress {
  const DownloadProgress({
    required this.phase,
    this.completed = 0,
    this.total = 0,
    this.issue,
    this.receivedBytes = 0,
    this.totalBytes,
    this.failedIssues = const [],
    this.counts,
    this.error,
  });

  final DownloadPhase phase;

  /// Issues stored in this run, out of [total] missing at the start.
  final int completed;
  final int total;

  /// The issue being fetched or imported.
  final int? issue;
  final int receivedBytes;
  final int? totalBytes;

  /// Issues skipped because the server or the archive was bad. They are
  /// retried on the next run.
  final List<int> failedIssues;

  /// What is stored once the run ends.
  final ArchiveCounts? counts;

  /// User-facing message when [phase] is failed.
  final String? error;

  bool get isFinished =>
      phase == DownloadPhase.done ||
      phase == DownloadPhase.cancelled ||
      phase == DownloadPhase.failed;
}

typedef IssueImporter = Future<ImportedIssue> Function(int, Uint8List);

/// Imports on a short-lived isolate: the 16 MB phile in issue 71 takes
/// seconds to normalise on a phone.
Future<ImportedIssue> importOnIsolate(int issue, Uint8List bytes) =>
    Isolate.run(() => importIssueArchive(issue, bytes));

class ArchiveDownloader {
  ArchiveDownloader({
    required this.source,
    required this.store,
    this.importer = importOnIsolate,
    this.politeDelay = const Duration(seconds: 1),
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final ArchiveSource source;
  final ArchiveStore store;
  final IssueImporter importer;

  /// Pause between issue downloads, to be gentle with the archive.
  final Duration politeDelay;
  final DateTime Function() _clock;

  Stream<DownloadProgress> run({CancelToken? cancel}) {
    final token = cancel ?? CancelToken();
    final controller = StreamController<DownloadProgress>();
    unawaited(_run(token, controller.add).whenComplete(controller.close));
    return controller.stream;
  }

  Future<void> _run(
    CancelToken cancel,
    void Function(DownloadProgress) emit,
  ) async {
    var completed = 0;
    var total = 0;
    final failed = <int>[];

    Future<void> finish(DownloadPhase phase, {String? error}) async {
      emit(
        DownloadProgress(
          phase: phase,
          completed: completed,
          total: total,
          failedIssues: List.unmodifiable(failed),
          counts: await store.counts(),
          error: error,
        ),
      );
    }

    try {
      emit(const DownloadProgress(phase: DownloadPhase.checking));
      final available = await source.availableIssues(cancel: cancel);
      final stored = await store.storedIssueNumbers();
      final missing = [
        for (final n in available)
          if (!stored.contains(n)) n,
      ];
      total = missing.length;

      // Record what exists before downloading anything, so the library can
      // list undownloaded issues even if this run fails.
      final dates = await source.releaseDates(cancel: cancel);
      await store.saveCatalog({for (final n in available) n: dates[n]});
      if (missing.isEmpty) return await finish(DownloadPhase.done);

      for (final (index, issue) in missing.indexed) {
        if (index > 0) await _pause(cancel);
        cancel.throwIfCancelled();
        emit(
          DownloadProgress(
            phase: DownloadPhase.downloading,
            completed: completed,
            total: total,
            issue: issue,
            failedIssues: List.unmodifiable(failed),
          ),
        );
        try {
          final bytes = await source.fetchIssue(
            issue,
            cancel: cancel,
            onProgress: (received, size) => emit(
              DownloadProgress(
                phase: DownloadPhase.downloading,
                completed: completed,
                total: total,
                issue: issue,
                receivedBytes: received,
                totalBytes: size,
                failedIssues: List.unmodifiable(failed),
              ),
            ),
          );
          cancel.throwIfCancelled();
          emit(
            DownloadProgress(
              phase: DownloadPhase.importing,
              completed: completed,
              total: total,
              issue: issue,
              failedIssues: List.unmodifiable(failed),
            ),
          );
          if (await _importAndSave(issue, bytes, dates[issue])) {
            completed++;
          } else {
            failed.add(issue);
          }
        } on ArchiveHttpException {
          failed.add(issue);
        }
      }
      await finish(DownloadPhase.done);
    } on CancelledException {
      await finish(DownloadPhase.cancelled);
    } on ArchiveNetworkException catch (e) {
      await finish(DownloadPhase.failed, error: e.message);
    } on ArchiveHttpException catch (e) {
      // The issue list itself could not be fetched.
      await finish(
        DownloadPhase.failed,
        error:
            'The Phrack archive returned an error (HTTP ${e.statusCode}). '
            'Try again later.',
      );
    }
  }

  /// Imports and stores one issue; false if it could not be. An issue that
  /// fails, for any reason, is reported and the run moves on: one bad
  /// archive (or a parser bug it reveals) must never stop the rest.
  Future<bool> _importAndSave(
    int issue,
    Uint8List bytes,
    DateTime? releaseDate,
  ) async {
    try {
      final imported = await importer(issue, bytes);
      await store.saveIssue(
        imported,
        fetchedAt: _clock().toUtc(),
        releaseDate: releaseDate,
      );
      return true;
    } on ArchiveFormatException {
      return false;
    } on Object catch (e, s) {
      developer.log(
        'issue $issue could not be imported',
        name: 'atdt.download',
        error: e,
        stackTrace: s,
      );
      return false;
    }
  }

  Future<void> _pause(CancelToken cancel) async {
    if (politeDelay == Duration.zero) return;
    final step = const Duration(milliseconds: 100);
    var waited = Duration.zero;
    while (waited < politeDelay) {
      cancel.throwIfCancelled();
      await Future<void>.delayed(step);
      waited += step;
    }
  }
}
