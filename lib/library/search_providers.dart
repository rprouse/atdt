import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../download/download_controller.dart';
import '../search/search_query.dart';
import '../storage/archive_database.dart';

/// Keeps the search index in step with the archive, and reports progress.
///
/// It follows the index status, so philes stored by a download, or found
/// unindexed after an upgrade, are indexed as they appear. SQLite runs on
/// drift's background isolate and large philes decode on their own
/// isolate (`readAllLines`), so indexing never blocks the UI.
class SearchIndexer extends Notifier<SearchIndexStatus?> {
  bool _running = false;

  @override
  SearchIndexStatus? build() {
    final db = ref.watch(archiveDatabaseProvider);
    final sub = db.watchSearchIndexStatus().listen((status) {
      state = status;
      if (!status.complete) unawaited(_run(db));
    });
    ref.onDispose(sub.cancel);
    return null;
  }

  Future<void> _run(ArchiveDatabase db) async {
    if (_running) return;
    _running = true;
    try {
      // Re-check after each pass: a download may store more philes meanwhile.
      while (ref.mounted) {
        final ids = await db.unindexedPhileIds();
        if (ids.isEmpty) break;
        for (final id in ids) {
          if (!ref.mounted) return;
          await db.indexPhile(id, await db.readAllLines(id));
        }
      }
    } on Object catch (e, s) {
      // The next status change (e.g. another download) retries.
      developer.log(
        'search indexing stopped',
        name: 'atdt.search',
        error: e,
        stackTrace: s,
      );
    } finally {
      _running = false;
    }
  }
}

final searchIndexerProvider =
    NotifierProvider<SearchIndexer, SearchIndexStatus?>(SearchIndexer.new);

/// What the search screen asks for. A record, so equal requests share one
/// provider.
typedef SearchRequest = ({String text, int from, int to, bool titlesOnly});

class SearchResults {
  const SearchResults({
    required this.query,
    required this.hits,
    required this.took,
  });

  final SearchQuery query;
  final List<SearchHit> hits;
  final Duration took;

  int get matchingLines => hits.fold(0, (n, h) => n + h.matchingLines);
}

final searchResultsProvider = FutureProvider.autoDispose
    .family<SearchResults, SearchRequest>((ref, request) async {
      // Searched again when indexing finishes, so early results fill in.
      ref.watch(searchIndexerProvider.select((s) => s?.complete ?? true));
      final query = SearchQuery.parse(request.text);
      if (query.isEmpty) {
        return SearchResults(query: query, hits: const [], took: Duration.zero);
      }
      final db = ref.watch(archiveDatabaseProvider);
      final watch = Stopwatch()..start();
      final hits = await db.search(
        query.toMatchExpression(),
        fromIssue: request.from,
        toIssue: request.to,
        titlesOnly: request.titlesOnly,
      );
      return SearchResults(query: query, hits: hits, took: watch.elapsed);
    });

/// A result's matching line, read only when its row is on screen.
final snippetProvider = FutureProvider.autoDispose.family<String?, (int, int)>(
  (ref, at) => ref.watch(archiveDatabaseProvider).readLine(at.$1, at.$2),
);
