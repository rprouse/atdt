import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../reader/reader_font.dart';
import '../reader/reader_screen.dart';
import '../reader/reader_settings.dart';
import '../search/search_query.dart';
import '../storage/archive_database.dart';
import 'library_providers.dart';
import 'search_providers.dart';

/// Full-text search over every downloaded phile. Works offline: it only
/// reads the on-device index.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _field = TextEditingController();
  Timer? _debounce;
  String _text = '';

  /// Null means every downloaded issue, so new downloads are included.
  RangeValues? _range;
  bool _titlesOnly = false;

  /// Shown while the next results load, so the list doesn't flash empty
  /// on every keystroke.
  SearchResults? _shown;

  @override
  void dispose() {
    _debounce?.cancel();
    _field.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: 250),
      () => setState(() => _text = text),
    );
  }

  void _submit(String text) {
    _debounce?.cancel();
    setState(() => _text = text);
  }

  @override
  Widget build(BuildContext context) {
    final downloaded = [
      for (final issue
          in ref.watch(libraryIssuesProvider).value ?? const <LibraryIssue>[])
        if (issue.downloaded) issue.number,
    ];
    final first = downloaded.isEmpty ? 0 : downloaded.last;
    final last = downloaded.isEmpty ? 0 : downloaded.first;
    final range = _range ?? RangeValues(first.toDouble(), last.toDouble());
    final status = ref.watch(searchIndexerProvider);

    final request = (
      text: _text,
      from: range.start.round(),
      to: range.end.round(),
      titlesOnly: _titlesOnly,
    );
    final results = _text.trim().isEmpty
        ? null
        : ref.watch(searchResultsProvider(request));
    if (results?.value case final value?) _shown = value;
    if (results == null) _shown = null;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          key: const ValueKey('search-field'),
          controller: _field,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: 'Search Phrack',
            border: InputBorder.none,
          ),
          onChanged: _onChanged,
          onSubmitted: _submit,
        ),
        actions: [
          if (_field.text.isNotEmpty)
            IconButton(
              tooltip: 'Clear',
              icon: const Icon(Icons.close),
              onPressed: () {
                _field.clear();
                _submit('');
              },
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  key: const ValueKey('issue-range'),
                  avatar: const Icon(Icons.filter_list, size: 18),
                  label: Text(
                    'Issues ${range.start.round()}–${range.end.round()}',
                  ),
                  onPressed: first == last
                      ? null
                      : () => _pickRange(first, last, range),
                ),
                FilterChip(
                  key: const ValueKey('titles-only'),
                  label: const Text('Titles and authors'),
                  selected: _titlesOnly,
                  onSelected: (on) => setState(() => _titlesOnly = on),
                ),
              ],
            ),
          ),
          if (status != null && !status.complete) _IndexProgress(status),
          if (results?.hasError ?? false)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Search failed: ${results!.error}'),
            ),
          Expanded(
            child: switch (_shown) {
              null when results != null => const Center(
                child: CircularProgressIndicator(),
              ),
              null => const _Hint(),
              final shown when shown.hits.isEmpty => const Center(
                child: Text('No matches'),
              ),
              final shown => _Results(results: shown),
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pickRange(int first, int last, RangeValues current) async {
    final picked = await showModalBottomSheet<RangeValues>(
      context: context,
      builder: (context) =>
          _RangeSheet(first: first, last: last, initial: current),
    );
    if (picked != null) setState(() => _range = picked);
  }
}

class _Hint extends StatelessWidget {
  const _Hint();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(24),
    child: Text(
      'Search every downloaded phile, offline.\n\n'
      'Words match anywhere on a line, and as prefixes: "hack" finds '
      '"hacker". Put a phrase in "double quotes".',
      textAlign: TextAlign.center,
    ),
  );
}

class _IndexProgress extends StatelessWidget {
  const _IndexProgress(this.status);

  final SearchIndexStatus status;

  @override
  Widget build(BuildContext context) => Padding(
    key: const ValueKey('index-progress'),
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Indexing ${status.indexed} of ${status.total} philes; '
          'results may be incomplete',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: status.total == 0 ? null : status.indexed / status.total,
        ),
      ],
    ),
  );
}

class _RangeSheet extends StatefulWidget {
  const _RangeSheet({
    required this.first,
    required this.last,
    required this.initial,
  });

  final int first;
  final int last;
  final RangeValues initial;

  @override
  State<_RangeSheet> createState() => _RangeSheetState();
}

class _RangeSheetState extends State<_RangeSheet> {
  late RangeValues _values = widget.initial;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Issues ${_values.start.round()} to ${_values.end.round()}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          RangeSlider(
            key: const ValueKey('issue-range-slider'),
            min: widget.first.toDouble(),
            max: widget.last.toDouble(),
            divisions: widget.last - widget.first,
            values: _values,
            labels: RangeLabels(
              '${_values.start.round()}',
              '${_values.end.round()}',
            ),
            onChanged: (v) => setState(() => _values = v),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              key: const ValueKey('issue-range-done'),
              onPressed: () => Navigator.of(context).pop(_values),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Results grouped by issue, newest first.
class _Results extends StatelessWidget {
  const _Results({required this.results});

  final SearchResults results;

  @override
  Widget build(BuildContext context) {
    final rows = <Object>[];
    int? issue;
    for (final hit in results.hits) {
      if (hit.issue != issue) rows.add(issue = hit.issue);
      rows.add(hit);
    }
    final ms = results.took.inMicroseconds / 1000;
    final philes = results.hits.length;
    final lines = results.matchingLines;
    final summary = [
      '$philes ${philes == 1 ? 'phile' : 'philes'}',
      if (lines > 0) '$lines ${lines == 1 ? 'line' : 'lines'}',
    ].join(', ');

    return ListView.builder(
      key: const ValueKey('search-results'),
      itemCount: rows.length + 1,
      itemBuilder: (context, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Text(
              '$summary · ${ms.toStringAsFixed(ms < 10 ? 1 : 0)} ms',
              key: const ValueKey('search-summary'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          );
        }
        return switch (rows[i - 1]) {
          final int issue => Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              'Issue $issue',
              key: ValueKey('issue-header-$issue'),
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          ),
          final SearchHit hit => _HitTile(hit: hit, query: results.query),
          _ => const SizedBox.shrink(),
        };
      },
    );
  }
}

class _HitTile extends StatelessWidget {
  const _HitTile({required this.hit, required this.query});

  final SearchHit hit;
  final SearchQuery query;

  @override
  Widget build(BuildContext context) {
    final line = hit.line;
    return ListTile(
      key: ValueKey('hit-${hit.phileId}'),
      title: Text(hit.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hit.author case final author?) Text(author),
          if (line != null) _Snippet(hit: hit, line: line, query: query),
        ],
      ),
      trailing: line == null ? null : Text('${hit.matchingLines}'),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ReaderScreen(
            phileId: hit.phileId,
            title: hit.title,
            revealLine: line,
            highlight: line == null ? null : query,
          ),
        ),
      ),
    );
  }
}

/// The first matching line, in the reader font, starting near its first
/// match so the match is visible in a narrow list.
class _Snippet extends ConsumerWidget {
  const _Snippet({required this.hit, required this.line, required this.query});

  final SearchHit hit;
  final int line;
  final SearchQuery query;

  /// Characters of context kept before a match further along the line.
  static const _lead = 12;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final raw = ref.watch(snippetProvider((hit.phileId, line))).value;
    if (raw == null) return const SizedBox(height: 18);
    final font = ref.watch(currentFontProvider);
    final theme = ref.watch(currentThemeProvider);
    // Never a system-font fallback: missing glyphs show as the font's own
    // placeholder, as in the reader.
    final text = font.coverage.substitute(raw);
    final matches = query.highlights(text);

    // Leading indentation is dropped; a match far along the line is
    // brought into view with a little context, marked by an ellipsis.
    var start = text.length - text.trimLeft().length;
    final truncated =
        matches.isNotEmpty && matches.first.$1 - start > _lead * 2;
    if (truncated) start = matches.first.$1 - _lead;
    final spans = <TextSpan>[if (truncated) const TextSpan(text: '…')];
    var at = start;
    for (final (s, e) in matches) {
      if (e <= at) continue;
      spans
        ..add(TextSpan(text: text.substring(at, s < at ? at : s)))
        ..add(
          TextSpan(
            text: text.substring(s < at ? at : s, e),
            style: TextStyle(backgroundColor: theme.selection),
          ),
        );
      at = e;
    }
    spans.add(TextSpan(text: text.substring(at)));

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text.rich(
        TextSpan(children: spans),
        key: ValueKey('snippet-${hit.phileId}'),
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.fade,
        style: TextStyle(
          fontFamily: font.family,
          fontFeatures: readerFontFeatures,
          fontSize: 13,
          color: theme.foreground,
        ),
      ),
    );
  }
}
